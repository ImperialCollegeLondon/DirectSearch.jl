export AddStoppingCondition


function AddStoppingCondition(p::DSProblem, c::T) where T <: AbstractStoppingCondition
    push!(p.stoppingconditions, c)
end

_check_stoppingconditions(p::DSProblem) = _check_stoppingconditions(p, p.stoppingconditions)
function _check_stoppingconditions(p::DSProblem, c::Vector{T}) where T <: AbstractStoppingCondition
    for condition in c
        #Stopping conditions return true if optimisation should continue,
        #false if the condition is met and optimisation should stop
        if CheckStoppingCondition(p, condition) == false
            setstatus(p, condition)
            return false
        end
    end

    return true
end

function setstatus(p, s::T) where T <: AbstractStoppingCondition
    p.status.optimization_status = StoppingConditionStatus(s)
end

StoppingConditionStatus(::T) where T <: AbstractStoppingCondition = "Unknown stopping condition status"

function _init_stoppingconditions(p::DSProblem)
    for c in p.stoppingconditions
        init_stoppingcondition(p, c)
    end
end

init_stoppingcondition(p::DSProblem, ::AbstractStoppingCondition) = nothing

_get_conditionindexes(p::DSProblem, target::Type) = _get_conditionindexes(p.stoppingconditions, target)
_get_conditionindexes(s::Vector{AbstractStoppingCondition}, target::Type) = 
    [i for (i,v) in enumerate(s) if typeof(v) == target]


#===== Built-in stopping conditions =====#

#Iteration limit
mutable struct IterationStoppingCondition <: AbstractStoppingCondition
    limit::Int64
end

StoppingConditionStatus(::IterationStoppingCondition) = "Iteration limit"

CheckStoppingCondition(p::DSProblem, s::IterationStoppingCondition) = p.status.iteration < s.limit

function init_stoppingcondition(p::DSProblem, s::IterationStoppingCondition)
    if s.limit == -1 
        error("Please set a maximum number of iterations")
    end
end

"""
    SetIterationLimit(p::DSProblem, i::Int)

Set the maximum number of iterations to `i`.
"""
function SetIterationLimit(p::DSProblem, i::Int)
    if i < p.status.iteration
        error("Cannot set iteration limit to lower than the number of iterations that have run")
    else
        iteration_indexes = _get_conditionindexes(p, IterationStoppingCondition)
        for index in iteration_indexes
            p.stoppingconditions[index].limit = i
        end
    end
end

"""
    BumpIterationLimit(p::DSProblem, i::Int)

Increase the iteration limit by `i`.
"""
function BumpIterationLimit(p::DSProblem, i::Int)
    iteration_indexes = _get_conditionindexes(p, IterationStoppingCondition)
    for index in iteration_indexes
        p.stoppingconditions[index].limit += i
    end
end


#Precision limit
struct MeshPrecisionStoppingCondition <: AbstractStoppingCondition end

StoppingConditionStatus(::MeshPrecisionStoppingCondition) = "Mesh Precision limit"

CheckStoppingCondition(p::DSProblem, ::MeshPrecisionStoppingCondition) = GetMeshSize(p) > min_mesh_size(p)
(GetMeshSize(p::DSProblem{T})::T) where T = p.config.mesh.Δᵐ
min_mesh_size(::DSProblem{Float64}) = 1.1102230246251565e-16
min_mesh_size(::DSProblem{T}) where T = eps(T)/2

#==========#
