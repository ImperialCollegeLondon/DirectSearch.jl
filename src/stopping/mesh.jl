export SetMinimumMeshSize

#Mesh size precision limit
mutable struct MeshPrecisionStoppingCondition{M<:AbstractMesh,T} <: AbstractStoppingCondition
    cont_min_mesh_size::T
    min_mesh_sizes::Vector{T}

    function MeshPrecisionStoppingCondition{M,T}(min_mesh_size::Union{T, Nothing}=nothing) where {T, M<:AbstractMesh}
        c = new()

        if min_mesh_size != nothing
            c.cont_min_mesh_size = min_mesh_size
        else
            c.cont_min_mesh_size = get_min_mesh_size(T)
        end

        return c
    end
end

function init_stoppingcondition(p::DSProblem{T}, s::MeshPrecisionStoppingCondition{IsotropicMesh{T}}) where T
    # Nothing to do here
    return nothing
end

function init_stoppingcondition(p::DSProblem{T}, s::MeshPrecisionStoppingCondition{AnisotropicMesh{T}}) where T
    s.min_mesh_sizes = map(δ_min -> δ_min > 0 ? δ_min : s.cont_min_mesh_size, p.config.mesh.δ_min)
end

StoppingConditionStatus(::MeshPrecisionStoppingCondition) = "Mesh Precision limit"

function CheckStoppingCondition(p::DSProblem{T}, s::MeshPrecisionStoppingCondition{IsotropicMesh{T}}) where T
    return p.config.mesh.Δᵐ > s.cont_min_mesh_size
end

function CheckStoppingCondition(p::DSProblem{T}, s::MeshPrecisionStoppingCondition{AnisotropicMesh{T}}) where T
    if p.config.mesh.only_granular
        p.config.mesh.l > -50
    else
        any(p.config.mesh.δ .> s.min_mesh_sizes)
    end
end


(GetMeshSizeVector(p::DSProblem{T})::Vector{T}) where T =

get_min_mesh_size(::Type{Float64}) = 1.1102230246251565e-16
get_min_mesh_size(::Type{T}) where T = eps(T)/2

"""
    SetMinimumMeshSize(p::DSProblem{T}, i::T) where T

Set the minimum mesh size for continuous variables.
"""
function SetMinimumMeshSize(p::DSProblem{T}, i::T) where T
    if i <= 0
        error("Minimum mesh size must be positive.")
    else
        mesh_precision_indexes = _get_conditionindexes(p, MeshPrecisionStoppingCondition)
        for index in mesh_precision_indexes
            p.stoppingconditions[index].cont_min_mesh_size = i
        end
    end
end
