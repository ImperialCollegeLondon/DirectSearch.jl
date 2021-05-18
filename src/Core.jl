using LinearAlgebra
using Distributed
using SharedArrays

export DSProblem, SetObjective, SetInitialPoint, SetVariableRange,
       SetOpportunisticEvaluation, SetSense, SetVariableRanges, Optimize!,
       SetIterationLimit, BumpIterationLimit, SetMaxEvals


"""
	DSProblem{T}(N::Int; poll::AbstractPoll=LTMADS{T}(),
                         search::AbstractSearch=NullSearch(),
                         objective::Union{Function,Nothing}=nothing,
                         initial_point::Vector=zeros(T, N),
                         iteration_limit::Int=1000,
                         )

Return a problem definition for an `N` dimensional problem.

`poll` and `search` specify the poll and search step algorithms to use. The default
choices are (LTMADS)[@ref] and (NullSearch)[@ref] respectively.

Note that if working with `Float64` (normally the case) then the type
parameterisation can be ignored.
"""
mutable struct DSProblem{T, MT, ST, PT, CT} <: AbstractProblem{T} where {MT <: AbstractMesh, ST <: AbstractSearch, PT <: AbstractPoll, CT <: AbstractCache}
    #= Problem Definition =#
    objective::Function
    constraints::Constraints{T}
    #Problem size
    N::Int
    user_initial_point::Union{Vector{T},Nothing}
    #Barrier threshold
    h_max::T
    sense::ProblemSense

    #TODO incumbent points should be sets not points, therefore change to vectors of points
    #and remove type unions

    #= Working Variables =#
    #Feasible incumbent point
    x::Union{Vector{T},Nothing}
    #Feasible incumbent point evaluated cost
    x_cost::Union{T,Nothing}
    #Infeasible incumbent point
    i::Union{Vector{T},Nothing}
    #Infeasible incumbent point evaluated cost
    i_cost::Union{T,Nothing}

    cache::CT

    #= Runtime data =#
    status::Status

    #= Solver Config =#
    config::Config{T, MT, ST, PT}

    stoppingconditions::Vector{AbstractStoppingCondition}

    full_output::Bool

    DSProblem(N::Int;kwargs...) = DSProblem{Float64}(N; kwargs...)

    function DSProblem{T}(N::Int;
                          poll::AbstractPoll=LTMADS{T}(),
                          search::AbstractSearch=NullSearch(),
                          objective::Union{Function,Nothing}=nothing,
                          initial_point::Vector=zeros(T, N),
                          iteration_limit::Int=1000,
                          function_evaluation_limit::Int=5000,
                          sense::ProblemSense=Min,
                          full_output::Bool=false,
                          kwargs...
                         ) where T

        p = new{T, Mesh{T}, typeof(search), typeof(poll), PointCache{T}}()

        p.N = N
        p.user_initial_point = convert(Vector{T},initial_point)

        p.sense = sense

        p.config = Config{T}(N, poll, search, Mesh{T}(N);kwargs...)

        p.status = Status()
        p.cache = PointCache{T}()
        p.constraints = Constraints{T}()

        p.stoppingconditions = AbstractStoppingCondition[
            IterationStoppingCondition(iteration_limit),
            FunctionEvaluationStoppingCondition(function_evaluation_limit),
            MeshPrecisionStoppingCondition(),
        ]

        p.x = nothing
        p.x_cost = nothing
        p.i = nothing
        p.i_cost = nothing

        if objective != nothing
            p.objective = objective
        end

        p.full_output = full_output

        return p
    end
end

MeshUpdate!(p::DSProblem, result::IterationOutcome) =
    MeshUpdate!(p.config.mesh, p.config.poll, result)

"""
    SetMaxEvals(p::DSProblem, m::Int)

Set the maximum number of simultaneous function evaluations that can be run.
By default this will be set 1.

If (DirectSearch.function_evaluation)[@ref] is not overriden (e.g. for sending
calculation to a cluster) then setting this to a number greater than your PC's
number of threads will result in no improvement.
"""
function SetMaxEvals(p::DSProblem, m::Int)
    if m > p.config.num_procs
        println("$m is larger than the number of workers that Julia was started with ($(p.config.num_procs))")
        println("Setting maximum number of workers to $(p.config.num_procs)")
        println("Start Julia with the option `-p N` where N is the number of additional processes")
        p.config.max_simultanious_evaluations = p.config.num_procs
    else
        p.config.max_simultanious_evaluations = m
    end
end

"""
    SetObjective(p::DSProblem, obj::Function)

Sets the target objective function to solve. `obj` should take a vector and return
a single cost value.
"""
function SetObjective(p::DSProblem, obj::Function)
    if p.sense == Min
        p.objective = obj
    else
        p.objective = x -> -obj(x)
    end
end

"""
    SetSense(p::DSProblem, sense::ProblemSense )

Set the problem sense. Valid values for `sense` are `DS.Min` and `DS.Max`.
"""
function SetSense(p::DSProblem, sense::ProblemSense)
    p.sense = sense
end

"""
    SetInitialPoint(p::DSProblem{T}, x::Vector{T}) where T

Set the initial incumbent point to `x`. This must be of the correct dimension. If using
any extreme barrier constraints then it must also satisfy these constraints.
"""
function SetInitialPoint(p::DSProblem{T}, x::Vector{T}) where T
    size(x, 1) == p.N || error("Point dimensions don't match problem definition")
    #TODO Check against constraints
    p.user_initial_point = x
end

"""
    SetOpportunisticEvaluation(p::DSProblem; opportunistic::Bool=true)

Set/unset opportunistic evaluation (enables by default).

When using opportunistic evaluation the first allowable evaluated point with an
improved cost is set as the new incumbent solution. If using progressive barrier
constraints this point may be infeasible.
"""
function SetOpportunisticEvaluation(p::DSProblem; opportunistic::Bool=true)
    p.config.opportunistic = opportunistic
end

function EvaluateInitialPoint(p::DSProblem)
    p.user_initial_point == Nothing() && return
    feasibility = ConstraintEvaluation(p.constraints, p.user_initial_point)
    if feasibility == StrongInfeasible
        error("Initial point must be feasible")
    elseif feasibility == WeakInfeasible
        p.i = p.user_initial_point
        p.i_cost = p.objective(p.user_initial_point)
        CachePush(p, p.i, p.i_cost)
    elseif feasibility == Feasible
        p.x = p.user_initial_point
        p.x_cost = p.objective(p.user_initial_point)
        CachePush(p, p.x, p.x_cost)
    end

    p.status.function_evaluations += 1

    p.full_output && InitialPointEvaluationOutput(p, feasibility)
end


#TODO review if this is the kind of scaling we want to do
"""
	SetVariableRange(p::DSProblem{T}, index::Int, l::T, u::T) where T

Set the expected range of the variable with index `i` to between lower (`l`) and upper (`u`)
values. This **does not** create a constraint, and is only used for scaling when a variable
varies with a significantly different scale to the others.
"""
function SetVariableRange(p::DSProblem{T}, index::Int, l::T, u::T) where T
    1 <= index <= p.N || error("Invalid variable index, should be in range 1 to $(p.N).")
    p.config.meshscale[index] = 0.1(u-l)
end

"""
	SetVariableRanges(p::DSProblem{T}, l::Vector{T}, u::Vector{T}) where T

Call [`SetVariableRange`](@ref) for each variable. The vectors `l` and `u` should contain
a lower and upper bound for each variable. If it is desired to keep a variable at default
scaling, then give it upper and lower bounds of `-5` and `5` respectively.
"""
function SetVariableRanges(p::DSProblem{T}, l::Vector{T}, u::Vector{T}) where T
    size(l, 1) == p.N || error("Lower bound vector dimensions don't match problem definition")
    size(u, 1) == p.N || error("Upper bound vector dimensions don't match problem definition")
    p.config.meshscale = @. 0.1(u-l)
end

"""
    Optimize!(p::DSProblem)

Run the direct search algorithm on problem `p`.

`p` must have had its initial point and objective function set. If extreme
barrier constraints have been set then the initial point must be value for
those constraints.
"""
function Optimize!(p::DSProblem)
    #TODO check that problem definition is complete
    Setup(p)

    while _check_stoppingconditions(p)
        p.full_output && OutputIterationDetails(p)
        OptimizeLoop(p)
    end

    Finish(p)
end

#Initialise solver
function Setup(p)
    p.status.start_time = time()
    _init_stoppingconditions(p)
    EvaluateInitialPoint(p)
    CacheOrderPush(p)
end

#A single iteration of the search->poll->update algorithm loop
function OptimizeLoop(p)
    if p.full_output
        println("Search step:\n")
    end
    result = Search(p)

    if p.full_output && !(p.config.search isa NullSearch)
        println("\tResult of Search step: $result\n")
    end

    if p.full_output
        println("Poll step:\n")
        if result !== Unsuccessful
            println("\tSkipping Poll step.\n")
        end
    end

    #If search fails, run poll
    if result == Unsuccessful
        result = Poll(p)
        if p.full_output
            println("\tResult of Poll step: $result\n")
        end
    end

    result != Unsuccessful && CacheOrderPush(p)

    #pass the result of search/poll to update
    MeshUpdate!(p, result)

    p.status.iteration += 1
end

#Cleanup and reporting
function Finish(p)
    p.status.runtime_total = time() - p.status.start_time
    ReportFinal(p)
end

"""
    EvaluatePoint!(p::DSProblem{FT}, trial_points)::IterationOutcome where {FT<:AbstractFloat}

Determine whether the set of trial points result in a dominating, improving, or unsuccesful
algorithm iteration. Update the feasible and infeasible incumbent points of `p`.
"""
function EvaluatePoint!(p::DSProblem{FT}, trial_points::Vector{Vector{FT}})::IterationOutcome where {FT<:AbstractFloat}
    #TODO could split into an evaluation function and an update function
    isempty(trial_points) && return Unsuccessful

    #Variables to store the best evaluated points
    feasible_point = isnothing(p.x) ? FT(Inf) * ones(p.N) : p.x
    feasible_cost = isnothing(p.x_cost) ? FT(Inf) : p.x_cost
    infeasible_point = isnothing(p.i) ? FT(Inf) * ones(p.N) : p.i
    infeasible_cost = isnothing(p.i_cost) ? FT(Inf) : p.i_cost

    #The current minimum hmax value for all collections
    h_min = GetOldHmaxSum(p.constraints)

    if p.full_output
        println("\tPoint evaluation:\n")
    end

    #Iterate over all trial points
    for i=1:length(trial_points)
        point = trial_points[i]

        feasibility = ConstraintEvaluation(p.constraints, point)

        # Point violates h_max on at least one constraint collection
        feasibility == StrongInfeasible && continue

        #Point is feasible for relaxed constraints, so evaluate it
        p.status.blackbox_time_total += @elapsed (cost, is_from_cache) = function_evaluation(p, point)

        #To determine if a point is dominating or improving the combined h_max is needed
        h = GetViolationSum(p.constraints, point)

        updated = false

        # Conditions met for a dominant point
        if feasibility == Feasible && cost < feasible_cost
            feasible_point = point
            feasible_cost = cost
            updated = true
        elseif feasibility == WeakInfeasible && h < h_min
            # Conditions met for an improving point (worse cost, but closer to being feasible) or
            # a dominant point (better cost and closer to feasibility)
            # Only record if it offers an improved constraint violation
            infeasible_point = point
            infeasible_cost = cost
            h_min = h
            updated = true
        end

        p.full_output && OutputPointEvaluation(i, point, cost, h, is_from_cache)

        #break if using opportunistic iteration
        updated && p.config.opportunistic && break
    end

    result = Unsuccessful

    incum_i_cost = isnothing(p.i_cost) ? FT(Inf) : p.i_cost
    incum_x_cost = isnothing(p.x_cost) ? FT(Inf) : p.x_cost


    # Dominates if there is a feasible improvement, or an infeasible point with
    # reduced violation (determined previously) as well as a cost lower than any
    # yet tested (feasible and infeasible)
    if feasible_cost < incum_x_cost
        result = Dominating
    elseif infeasible_cost < incum_i_cost && h_min < GetOldHmaxSum(p.constraints)
        result = Dominating
    elseif h_min < GetOldHmaxSum(p.constraints)
        result = Improving
    end

    if feasible_cost < incum_x_cost
        p.x = feasible_point
        p.x_cost = feasible_cost
    end

    if infeasible_cost < incum_i_cost || h_min < GetOldHmaxSum(p.constraints)
        p.i = infeasible_point
        p.i_cost = infeasible_cost
    end

    UpdateConstraints(p.constraints, h_min, result, p.x, p.i)

    return result
end

#Wrapper for matching to empty trial point arrays
(EvaluatePoint!(p::DSProblem{T}, trial_points::Vector)::IterationOutcome) where T =
    EvaluatePoint!(p, convert(Vector{Vector{T}}, trial_points))

"""
    function_evaluation(p::DSProblem{T}, trial_points::Vector{Vector{T}})::Vector{T} where T

Calculate the cost of the points in `trial_points` and return as a vector.

If the number of available workers is greater than one, and the max_simultanious_evaluations
value of `p` is greater than one then the calculation is distributed across
several cores.

Currently, this has significant overheads and is much slower than evaluating in a single threaded
manner on all testcases. This may give performance benefits when `f` is a heavy, single threaded
operation.

If a specialised way  of calling the function is needed then this function should be overriden, e.g.:

```
function DS.function_evaluation(p::DS.DSProblem{T}, trial_points::Vector{Vector{T}}) where T
	println("I am overriden")
	return map(p.objective, trial_points)
end
```
"""
function function_evaluation(p::DSProblem{T},
                             trial_points::Vector{Vector{T}})::Vector{T} where T
    if p.config.max_simultanious_evaluations > 1
        costs = SharedArray{T,1}((length(trial_points)))
        #TODO try with threads, might be faster
        @sync @distributed for i in 1:length(trial_points)
            costs[i] = p.objective(trial_points[i])
        end
        return costs
    else
        return map(p.objective, trial_points)
    end
end

"""
	function_evaluation(p::DSProblem{T}, trial_point::Vector{T})::(T, Bool) where T

Evaluate a single trial point with the objective function of `p`.

By default calls the function with the trial point and returns the result. Override to
provide custom evaluation behaviour.
"""
function function_evaluation(p::DSProblem{T},
                             trial_point::Vector{T})::Tuple{T, Bool} where T
    if CacheQuery(p, trial_point)
        p.status.cache_hits += 1
        return (CacheGet(p, trial_point), true)
    end
    cost = p.objective(trial_point)
    p.status.function_evaluations += 1
    CachePush(p, trial_point, cost)
	return (cost, false)
end
