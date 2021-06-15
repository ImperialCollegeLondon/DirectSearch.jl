using LinearAlgebra
using Distributed
using SharedArrays

export DSProblem, SetObjective, SetInitialPoint, SetVariableBound, SetMaxEvals,
       SetOpportunisticEvaluation, SetSense, SetVariableBounds, Optimize!, SetGranularity,
       SetGranularities


"""
	DSProblem{T}(N::Int; poll::AbstractPoll=LTMADS{T}(),
                         search::AbstractSearch=NullSearch(),
                         objective::Union{Function,Nothing}=nothing,
                         initial_point::Vector=zeros(T, N),
                         iteration_limit::Int=1000,
                         function_evaluation_limit::Int=5000,
                         sense::ProblemSense=Min,
                         full_output::Bool=false,
                         granularity::Vector=zeros(T, N),
                         min_mesh_size::Union{T,Nothing}=nothing,
                         min_poll_size::Union{T,Nothing}=nothing,
                         kwargs...
                         ) where T

Return a problem definition for an `N` dimensional problem.

`poll` and `search` specify the poll and search step algorithms to use. The default
choices are [`LTMADS`](@ref) and [`NullSearch`](@ref) respectively.

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
    granularity::Vector{T}
    lower_bounds::Vector{Union{T, Nothing}}
    upper_bounds::Vector{Union{T, Nothing}}
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
    status::Status{T}

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
                          granularity::Vector=zeros(T, N),
                          min_mesh_size::Union{T,Nothing}=nothing,
                          min_poll_size::Union{T,Nothing}=nothing,
                          kwargs...
                         ) where T

        p = new{T, Mesh{T}, typeof(search), typeof(poll), PointCache{T}}()

        p.N = N
        p.user_initial_point = convert(Vector{T},initial_point)
        p.granularity = convert(Vector{T},granularity)
        p.lower_bounds = fill(nothing, N)
        p.upper_bounds = fill(nothing, N)

        p.sense = sense

        p.config = Config{T}(N, poll, search, Mesh{T}(N);kwargs...)

        p.status = Status{T}()
        p.cache = PointCache{T}()
        p.constraints = Constraints{T}()

        p.stoppingconditions = AbstractStoppingCondition[
            IterationStoppingCondition(iteration_limit),
            FunctionEvaluationStoppingCondition(function_evaluation_limit),
            MeshPrecisionStoppingCondition{T}(min_mesh_size),
            PollPrecisionStoppingCondition{T}(min_poll_size)
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
    MeshUpdate!(p.config.mesh, p.config.poll, result, p.status.success_direction)

"""
    SetMaxEvals(p::DSProblem, max::Bool=true)

Set/unset parallel blackbox evaluations.
The number of threads Julia was started with will be used.

Note that using parallel blackbox evaluations will only result in reduced runtime
for problems that have long blackbox evaluations.
"""
function SetMaxEvals(p::DSProblem, max::Bool=true)
    if max
        p.config.max_simultaneous_evaluations = p.config.num_threads
        if p.config.num_threads == 1
            println("Julia was started single-threaded.")
            println("Start Julia with the option `--threads N` where N is the number of threads,\n to use parallel blackbox evaluations.")
        end
    else
        p.config.max_simultaneous_evaluations = 1
    end
    p.config.parallel_lock = ReentrantLock()
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
    SetGranularity(p::DSProblem{T}, index::Int, g::T) where T

Set the granularity of the variable with index `i` to `g`.
"""
function SetGranularity(p::DSProblem{T}, index::Int, g::T) where T
    1 <= index <= p.N || error("Invalid variable index, should be in range 1 to $(p.N).")
    g >= 0 || error("Granularity has to be non-negative.")

    p.granularity[index] = g
end

"""
    SetGranularities(p::DSProblem{T}, g::Vector{T}) where T

Call [`SetGranularity`](@ref) for each variable. The vector `g` should contain the granularity 
for each variable.
"""
function SetGranularities(p::DSProblem{T}, g::Vector{T}) where T
    size(g, 1) == p.N || error("Granularity vector dimensions don't match problem definition")

    for i=1:p.N
        SetGranularity(p, i, g[i])
    end
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

"""
    EvaluateInitialPoint(p::DSProblem)

Evaluate the initial point.

Throws an error if the initial point is not feasible.
"""
function EvaluateInitialPoint(p::DSProblem)
    p.user_initial_point == Nothing() && return
    feasibility = ConstraintEvaluation(p, p.user_initial_point)
    if feasibility == StrongInfeasible
        error("Initial point must be feasible")
    elseif feasibility == WeakInfeasible
        p.i = p.user_initial_point
        p.i_cost = round(p.objective(p.user_initial_point), digits=p.config.cost_digits)
        CachePush(p, p.i, p.i_cost)
    elseif feasibility == Feasible
        p.x = p.user_initial_point
        p.x_cost = round(p.objective(p.user_initial_point), digits=p.config.cost_digits)
        CachePush(p, p.x, p.x_cost)
    end

    p.status.function_evaluations += 1

    p.full_output && InitialPointEvaluationOutput(p, feasibility)
end


#TODO review if this is the kind of scaling we want to do
"""
	SetVariableBound(p::DSProblem{T}, index::Int, l::T, u::T) where T

Set the expected bounds of the variable with index `i` to between lower (`l`) and upper (`u`)
values. This **does not** create a constraint, and is only used for scaling when a variable
varies with a significantly different scale to the others.
"""
function SetVariableBound(p::DSProblem{T}, index::Int, l::T, u::T) where T
    1 <= index <= p.N || error("Invalid variable index, should be in range 1 to $(p.N).")
    
    p.lower_bounds[index] = isinf(l) ? nothing : l
    p.upper_bounds[index] = isinf(u) ? nothing : u
end

"""
	SetVariableBounds(p::DSProblem{T}, l::Vector{T}, u::Vector{T}) where T

Call [`SetVariableBound`](@ref) for each variable. The vectors `l` and `u` should contain
a lower and upper bound for each variable.
"""
function SetVariableBounds(p::DSProblem{T}, l::Vector{T}, u::Vector{T}) where T
    size(l, 1) == p.N || error("Lower bound vector dimensions don't match problem definition")
    size(u, 1) == p.N || error("Upper bound vector dimensions don't match problem definition")
    
    for i=1:p.N
        SetVariableBound(p, i, l[i], u[i])
    end
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
    _check_initial_point(p)
    MeshSetup!(p)
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
    if p.config.max_simultaneous_evaluations > 1
        EvaluatePointParallel!(p, trial_points)
    else
        EvaluatePointSequential!(p, trial_points)
    end
end

"""
    valuatePointSequential!(p::DSProblem{FT}, trial_points::Vector{Vector{FT}})::IterationOutcome where {FT<:AbstractFloat}

Single-threaded evaluation of set of trial points.
"""
function EvaluatePointSequential!(p::DSProblem{FT}, trial_points::Vector{Vector{FT}})::IterationOutcome where {FT<:AbstractFloat}
    #TODO could split into an evaluation function and an update function
    isempty(trial_points) && return Unsuccessful

    #Variables to store the best evaluated points
    feasible_point = isnothing(p.x) ? FT(Inf) * ones(p.N) : p.x
    feasible_cost = isnothing(p.x_cost) ? FT(Inf) : p.x_cost
    infeasible_point = isnothing(p.i) ? FT(Inf) * ones(p.N) : p.i
    infeasible_cost = isnothing(p.i_cost) ? FT(Inf) : p.i_cost
    successful_direction = nothing

    #The current minimum hmax value for all collections
    h_min = GetOldHmaxSum(p.constraints)

    if p.full_output
        println("\tPoint evaluation:\n")
    end

    #Iterate over all trial points
    for (i, point)=enumerate(trial_points)

        feasibility = ConstraintEvaluation(p, point)

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
            successful_direction = isnothing(p.status.directions) ? nothing : p.status.directions[i]
            updated = true
        elseif feasibility == WeakInfeasible && h < h_min
            # Conditions met for an improving point (worse cost, but closer to being feasible) or
            # a dominant point (better cost and closer to feasibility)
            # Only record if it offers an improved constraint violation
            infeasible_point = point
            infeasible_cost = cost
            h_min = h
            successful_direction = isnothing(p.status.directions) ? nothing : p.status.directions[i]
            updated = true
        end

        p.full_output && OutputPointEvaluation(i, point, cost, h, is_from_cache)

        #break if using opportunistic iteration
        updated && p.config.opportunistic && break
    end

    result = Unsuccessful

    incum_i_cost = isnothing(p.i_cost) ? FT(Inf) : p.i_cost
    incum_x_cost = isnothing(p.x_cost) ? FT(Inf) : p.x_cost

    p.status.directions = nothing


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

    p.status.success_direction = successful_direction

    UpdateConstraints(p.constraints, h_min, result, p.x, p.i)

    return result
end

"""
    EvaluatePointParallel!(p::DSProblem{FT}, trial_points::Vector{Vector{FT}})::IterationOutcome where {FT<:AbstractFloat}

Multi-threaded evaluation of set of trial points. Uses the number of threads that Julia was started with.
"""
function EvaluatePointParallel!(p::DSProblem{FT}, trial_points::Vector{Vector{FT}})::IterationOutcome where {FT<:AbstractFloat}
    #TODO could split into an evaluation function and an update function
    isempty(trial_points) && return Unsuccessful

    #Variables to store the best evaluated points
    feasible_point = isnothing(p.x) ? FT(Inf) * ones(p.N) : p.x
    feasible_cost = isnothing(p.x_cost) ? Threads.Atomic{FT}(FT(Inf)) : Threads.Atomic{FT}(p.x_cost)
    infeasible_point = isnothing(p.i) ? FT(Inf) * ones(p.N) : p.i
    infeasible_cost = isnothing(p.i_cost) ? Threads.Atomic{FT}(FT(Inf)) : Threads.Atomic{FT}(p.i_cost)
    successful_direction = nothing


    #The current minimum hmax value for all collections
    h_min = GetOldHmaxSum(p.constraints)

    updated = Threads.Atomic{Bool}(false)

    #Iterate over all trial points
    Threads.@threads for i=1:length(trial_points)
        point = trial_points[i]

        p.config.opportunistic && updated[] && break

        feasibility = ConstraintEvaluation(p, point)

        # Point violates h_max on at least one constraint collection
        feasibility == StrongInfeasible && continue

        #Point is feasible for relaxed constraints, so evaluate it
        p.status.blackbox_time_total += @elapsed (cost, is_from_cache) = function_evaluation_parallel(p, point)

        #To determine if a point is dominating or improving the combined h_max is needed
        h = GetViolationSumParallel(p, point)

        # Conditions met for a dominant point
        if feasibility == Feasible && cost < feasible_cost[]
            feasible_point = point
            Threads.atomic_xchg!(feasible_cost, cost)
            successful_direction = isnothing(p.status.directions) ? nothing : p.status.directions[i]
            # updated = true
            Threads.atomic_xchg!(updated, true)
        elseif feasibility == WeakInfeasible && h < h_min
            # Conditions met for an improving point (worse cost, but closer to being feasible) or
            # a dominant point (better cost and closer to feasibility)
            # Only record if it offers an improved constraint violation
            infeasible_point = point
            Threads.atomic_xchg!(infeasible_cost, cost)
            successful_direction = isnothing(p.status.directions) ? nothing : p.status.directions[i]
            h_min = h
            Threads.atomic_xchg!(updated, true)
        end

        p.full_output && OutputPointEvaluation(i, point, cost, h, is_from_cache, Threads.threadid())
    end

    result = Unsuccessful

    incum_i_cost = isnothing(p.i_cost) ? FT(Inf) : p.i_cost
    incum_x_cost = isnothing(p.x_cost) ? FT(Inf) : p.x_cost

    p.status.directions = nothing


    # Dominates if there is a feasible improvement, or an infeasible point with
    # reduced violation (determined previously) as well as a cost lower than any
    # yet tested (feasible and infeasible)
    if feasible_cost[] < incum_x_cost
        result = Dominating
    elseif infeasible_cost[] < incum_i_cost && h_min < GetOldHmaxSum(p.constraints)
        result = Dominating
    elseif h_min < GetOldHmaxSum(p.constraints)
        result = Improving
    end

    if feasible_cost[] < incum_x_cost
        p.x = feasible_point
        p.x_cost = feasible_cost[]
    end

    if infeasible_cost[] < incum_i_cost || h_min < GetOldHmaxSum(p.constraints)
        p.i = infeasible_point
        p.i_cost = infeasible_cost[]
    end

    p.status.success_direction = successful_direction

    UpdateConstraints(p.constraints, h_min, result, p.x, p.i)

    return result
end

#Wrapper for matching to empty trial point arrays
(EvaluatePoint!(p::DSProblem{T}, trial_points::Vector)::IterationOutcome) where T =
    EvaluatePoint!(p, convert(Vector{Vector{T}}, trial_points))

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
    cost = round(p.objective(trial_point), digits=p.config.cost_digits)
    p.status.function_evaluations += 1
    CachePush(p, trial_point, cost)
	return (cost, false)
end

"""
    function_evaluation_parallel(p::DSProblem{T}, trial_point::Vector{T})::Tuple{T, Bool} where T

Evaluate a single trial point with the objective function of `p` using multiple threads.
"""
function function_evaluation_parallel(p::DSProblem{T}, trial_point::Vector{T})::Tuple{T, Bool} where T
    if CacheQueryParallel(p, trial_point)
        p.status.cache_hits += 1
        return (CacheGetParallel(p, trial_point), true)
    end
    cost = p.objective(trial_point)
    p.status.function_evaluations += 1
    CachePushParallel(p, trial_point, cost)
	return (cost, false)
end

function _check_initial_point(p::DSProblem{T}) where T
    for i=1:p.N
        if p.granularity[i] > 0 && (p.user_initial_point[i] / p.granularity[i]) % 1 != 0
            error("Initial value of variable with index $i is not an integer multiple of its granularity.")
        end
    end
end
