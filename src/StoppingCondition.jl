export AddStoppingCondition


function AddStoppingCondition(p::DSProblem, c::T) where T <: AbstractStoppingCondition
    push!(p.stoppingconditions, c)
end

CheckStoppingConditions(p::DSProblem) = CheckStoppingConditions(p, p.stoppingconditions)
function CheckStoppingConditions(p::DSProblem, c::Vector{T}) where T <: AbstractStoppingCondition
    for condition in c
        #Stopping conditions return true if optimisation should continue,
        #false if the condition is met and optimisation should stop
        if CheckStoppingCondition(p, condition) == false
            SetStatus(p, condition)
            return false
        end
    end

    return true
end

function SetStatus(p, s::T) where T <: AbstractStoppingCondition
    p.status.optimization_status = StoppingConditionStatus(s)
end

StoppingConditionStatus(::T) where T <: AbstractStoppingCondition = "Unknown stopping condition status"


SetupStoppingConditions(p::DSProblem) = SetupStoppingConditions(p.stoppingconditions)
function SetupStoppingConditions(s::Vector{AbstractStoppingCondition})
    for c in s
        SetupStoppingCondition(p, c)
    end
end

SetupStoppingCondition(p::DSProblem, ::AbstractStoppingCondition) = nothing

#===== Built-in stopping conditions =====#

#Iteration limit
mutable struct IterationStoppingCondition <: AbstractStoppingCondition
    limit::Int64
end

StoppingConditionStatus(::IterationStoppingCondition) = "Iteration limit"

CheckStoppingCondition(p::DSProblem, s::IterationStoppingCondition) = p.status.iteration < s.limit

function SetupStoppingCondition(p::DSProblem, s::IterationStoppingCondition)
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
        p.stoppingconditions[1].limit = i
    end
end

"""
    BumpIterationLimit(p::DSProblem, i::Int)

Increase the iteration limit by `i`.
"""
function BumpIterationLimit(p::DSProblem, i::Int)
    p.stoppingconditions[1].limit += i
end


#Precision limit
struct MeshPrecisionStoppingCondition <: AbstractStoppingCondition end

StoppingConditionStatus(::MeshPrecisionStoppingCondition) = "Mesh Precision limit"

CheckStoppingCondition(p::DSProblem, ::MeshPrecisionStoppingCondition) = GetMeshSize(p) > min_mesh_size(p)
(GetMeshSize(p::DSProblem{T})::T) where T = p.config.mesh.Δᵐ
min_mesh_size(::DSProblem{Float64}) = 1.1102230246251565e-16
min_mesh_size(::DSProblem{T}) where T = eps(T)/2

#==========#
