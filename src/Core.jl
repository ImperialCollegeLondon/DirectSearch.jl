using LinearAlgebra
using Distributed
using SharedArrays

export DSProblem, ProblemSense, SetObjective, SetInitialPoint, SetVariableRange, 
       SetVariableRanges, Optimize!, SetIterationLimit, BumpIterationLimit, SetMaxEvals

@enum ProblemSense Min Max
@enum OptimizationStatus Unoptimized PrecisionLimit IterationLimit



"""
	DSProblem{T}(N::Int; poll::AbstractPoll=LTMADS{T}(), 
                         search::AbstractSearch=NullSearch(),
                         objective::Union{Function,Nothing}=nothing,
                         initial_point::Vector{T}=zeros(T, N),
                         iteration_limit::Int=1000,
                         sense::ProblemSense=Min)

Return a problem definition for an `N` dimensional problem.

`poll` and `search` specify the poll and search step algorithms to use. The default
choices are (LTMADS)[@ref] and (NullSearch)[@ref] respectively.

Note that if working with `Float64` (normally the case) then the type
parameterisation can be ignored.
"""
mutable struct DSProblem{T} <: AbstractProblem{T}

    #Solver Config 
    mesh::AbstractMesh
    poll::AbstractPoll
    search::AbstractSearch

    #Problem Definition
    objective::Function
    constraints::Constraints
    sense::ProblemSense
    
    #TODO incumbent points should be sets not points, therefore change to vectors of points
    #and remove type unions 
    
    #Feasible Incumbent point
    x::Union{Vector{T},Nothing}
    #Feasible Incumbent point evaluated cost
    x_cost::Union{T,Nothing}

    #Infeasible Incumbent point
    i::Union{Vector{T},Nothing}
    #Infeasible Incumbent point evaluated cost
    i_cost::Union{T,Nothing}
 
    user_initial_point::Union{Vector{T},Nothing}

    #Problem size
    N::Int

    function_evaluations::Int

    iteration::Int
    iteration_limit::Int
    status::OptimizationStatus

    meshscale::Vector{T}

    cache::PointCache{T}

    num_procs::Int
    max_simultanious_evaluations::Int

    #Barrier threshold
    h_max::T

    DSProblem(N::Int;kwargs...) = DSProblem{Float64}(N; kwargs...)

    function DSProblem{T}(N::Int; 
                          poll::AbstractPoll=LTMADS{T}(), 
                          search::AbstractSearch=NullSearch(),
                          objective::Union{Function,Nothing}=nothing,
                          initial_point::Vector{T}=zeros(T, N),
                          iteration_limit::Int=1000,
                          sense::ProblemSense=Min
                         ) where T
                       
        p = new()
        
        p.N = N 
        p.mesh = Mesh{T}(N)
        p.poll = poll

        p.search = search
    
        p.iteration = 0
        p.function_evaluations = 0
        p.iteration_limit = iteration_limit
        p.status = Unoptimized
        p.sense = sense

        
        p.meshscale = ones(p.N)

        p.cache = PointCache{T}()

        p.num_procs = nworkers()
        p.max_simultanious_evaluations = 1
       
        p.x = nothing
        p.x_cost = nothing
        p.i = nothing
        p.i_cost = nothing
        
        if objective != nothing
            p.objective = objective
        end

        p.user_initial_point = initial_point


        p.constraints = Constraints{T}()
        return p
    end
end

MeshUpdate!(p::DSProblem, result::IterationOutcome) = MeshUpdate!(p.mesh, p.poll, result)

(GetMeshSize(p::DSProblem{T})::T) where T = p.mesh.Δᵐ

min_mesh_size(::DSProblem{Float64}) = 1.1102230246251565e-16
min_mesh_size(::DSProblem{T}) where T = eps(T)/2

"""
    SetMaxEvals(p::DSProblem, m::Int)

Set the maximum number of simultaneous function evaluations that can be run.
By default this will be set 1.

If (DirectSearch.function_evaluation)[@ref] is not overriden (e.g. for sending 
calculation to a cluster) then setting this to a number greater than your PC's 
number of threads will result in no improvement.
"""
function SetMaxEvals(p::DSProblem, m::Int)
    if m > p.num_procs
        println("$m is larger than the number of workers that Julia was started with ($(p.num_procs))")
        println("Setting maximum number of workers to $(p.num_procs)")
        println("Start Julia with the option `-p N` where N is the number of additional processes")
        p.max_simultanious_evaluations = p.num_procs
    else
        p.max_simultanious_evaluations = m
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
    SetIterationLimit(p::DSProblem, i::Int)

Set the maximum number of iterations to `i`.
"""
function SetIterationLimit(p::DSProblem, i::Int)
    if i < p.iteration
        error("Cannot set iteration limit to lower than the number of iterations that have run")
    else
        p.iteration_limit = i
    end
end

"""
    BumpIterationLimit(p::DSProblem, val::Int=100)

Increase the iteration limit by `i`.
"""
function BumpIterationLimit(p::DSProblem; i::Int=100)
    p.iteration_limit += i
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

function EvaluateInitialPoint(p::DSProblem)
    p.user_initial_point == Nothing() && return
    feasibility, _ = ConstraintEvaluation(p.constraints, p.user_initial_point)
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
    p.user_initial_point = Nothing()
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
    p.meshscale[index] = 0.1(u-l)
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
    p.meshscale = @. 0.1(u-l)
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
    EvaluateInitialPoint(p)

    while p.iteration < p.iteration_limit && GetMeshSize(p) >= min_mesh_size(p)

        result = Search(p)
        #If search fails, run poll
        if result == Unsuccessful
            result = Poll(p)
        end

        CachePush(p)

        #pass the result of search/poll to update
        MeshUpdate!(p, result)
        ConstraintUpdate!(p, result)

        p.iteration += 1
    end

    if p.iteration > p.iteration_limit 
        p.status = IterationLimit
    end
    if GetMeshSize(p) <= min_mesh_size(p)
        p.status = PrecisionLimit
    end

    #report_finish(p)
end

"""
    EvaluatePoint!(p::DSProblem{T}, trial_points)::IterationOutcome where T

Determine whether the set of trial points result in a dominating, improving, or unsuccesful
algorithm iteration. Update the feasible and infeasible incumbent points of `p`.
"""
function EvaluatePoint!(p::DSProblem{T}, trial_points)::IterationOutcome where T
    #TODO split into an evaluation function and an update function

    isempty(trial_points) && return Unsuccessful

    feasible_point = isnothing(p.x) ? Inf * ones(p.N) : p.x
    feasible_cost = isnothing(p.x_cost) ? Inf : p.x_cost
    infeasible_point = isnothing(p.i) ? Inf * ones(p.N) : p.i
    infeasible_cost = isnothing(p.i_cost) ? Inf : p.i_cost
    h_max_lim = GetHmaxSum(p.constraints)

    #The largest h_max value that is 
    h_max_update_val = 0.0

    for point in trial_points
        feasibility, h_max_sum = ConstraintEvaluation(p.constraints, point)

        # Point violates h_max on at least one constraint collection
        feasibility == StrongInfeasible && continue
        cost = function_evaluation(p, point)

        # Conditions met for a dominant point
        if feasibility == Feasible && cost < feasible_cost
            feasible_point = point
            feasible_cost = cost
        # Conditions met for an improving point (worse cost, but closer to being feasible) or 
        # a dominant point (better cost and closer to feasibility)
        elseif feasibility == WeakInfeasible && h_max_sum < h_max_lim
            infeasible_point = point
            infeasible_cost = cost
            h_max_lim = h_max_sum
            h_max_update_val = max(h_max_update_val, h_max_lim)
        end
    end

    outcome = Unsuccessful 

    p_i_cost_tmp = isnothing(p.i_cost) ? Inf : p.i_cost
    p_x_cost_tmp = isnothing(p.x_cost) ? Inf : p.x_cost

    # Dominates if there is a feasible improvement, or an infeasible point with
    # reduced violation (determined previously) as well as a cost lower than any
    # yet tested (feasible and infeasible)
    if feasible_cost < p_x_cost_tmp 
        outcome = Dominating
    elseif infeasible_cost < min(p_i_cost_tmp, p_x_cost_tmp) && h_max_lim < GetHmaxSum(p.constraints)
        outcome = Dominating
    elseif h_max_lim < GetHmaxSum(p.constraints)
        outcome = Improving
    end

    if feasible_cost < p_x_cost_tmp
        p.x = feasible_point
        p.x_cost = feasible_cost

    end
    if infeasible_cost < p_i_cost_tmp || h_max_lim < GetHmaxSum(p.constraints)
        p.i = infeasible_point
        p.i_cost = infeasible_cost
    end
     
    return outcome
end

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
    if p.max_simultanious_evaluations > 1
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
	function_evaluation(p::DSProblem{T}, trial_point::Vector{T})::T where T

Evaluate a single trial point with the objective function of `p`. 

By default calls the function with the trial point and returns the result. Override to 
provide custom evaluation behaviour.
"""
function function_evaluation(p::DSProblem{T}, 
                             trial_point::Vector{T})::T where T
    CacheQuery(p, trial_point) && return CacheGet(p, trial_point)
    cost = p.objective(trial_point)
    p.function_evaluations += 1
    CachePush(p, trial_point, cost)  
	return cost
end
