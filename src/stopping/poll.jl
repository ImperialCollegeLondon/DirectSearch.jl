export SetMinimumPollSize

#Poll size precision limit
mutable struct PollPrecisionStoppingCondition{M<:AbstractMesh, T} <: AbstractStoppingCondition
    cont_min_poll_size::T
    min_poll_sizes::Vector{T}

    function PollPrecisionStoppingCondition{M,T}(min_poll_size::Union{T, Nothing}=nothing) where {T, M<:AbstractMesh}
        c = new()

        if min_poll_size != nothing
            c.cont_min_poll_size = min_poll_size
        else
            c.cont_min_poll_size = get_min_poll_size(T)
        end

        return c
    end
end

function init_stoppingcondition(p::DSProblem, s::PollPrecisionStoppingCondition)
    s.min_poll_sizes = map(δ_min -> δ_min > 0 ? δ_min : s.cont_min_poll_size, p.config.mesh.δ_min)
end

StoppingConditionStatus(::PollPrecisionStoppingCondition) = "Poll Precision limit"

function CheckStoppingCondition(p::DSProblem, s::PollPrecisionStoppingCondition)
    if p.config.mesh.only_granular
        p.config.mesh.l > -50
    else
        any(GetPollSizeVector(p) .> s.min_poll_sizes)
    end
end


(GetPollSizeVector(p::DSProblem{T})::Vector{T}) where T = p.config.mesh.Δ

get_min_poll_size(::Type{Float64}) = 1.1102230246251565e-16
get_min_poll_size(::Type{T}) where T = eps(T)/2

"""
    SetMinimumPollSize(p::DSProblem{T}, i::T) where T

Set the minimum poll size for continuous variables.
"""
function SetMinimumPollSize(p::DSProblem{T}, i::T) where T
    if i <= 0
        error("Minimum poll size must be positive.")
    else
        poll_precision_indexes = _get_conditionindexes(p, PollPrecisionStoppingCondition)
        for index in poll_precision_indexes
            p.stoppingconditions[index].cont_min_poll_size = i
        end
    end
end
