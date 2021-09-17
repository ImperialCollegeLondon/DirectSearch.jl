export RuntimeStoppingCondition


#Runtime limit
mutable struct RuntimeStoppingCondition <: AbstractStoppingCondition
    limit::Float64
end

StoppingConditionStatus(::RuntimeStoppingCondition) = "Runtime limit"

CheckStoppingCondition(p::DSProblem, s::RuntimeStoppingCondition) = (time() - p.status.start_time) < s.limit

function init_stoppingcondition(::DSProblem, s::RuntimeStoppingCondition)
    if s.limit <= 0
        error("Runtime limit must be positive.")
    end
end

"""
    SetRuntimeLimit(p::DSProblem, i::Float64)

Set the runtime limit to `i`.
"""
function SetRuntimeLimit(p::DSProblem, i::Float64)
    if i < p.status.runtime_total
        error("Cannot set runtime limit to lower than the runtime of the previous run")
    elseif i <= 0
        error("Runtime limit has to be positive.")
    else
        runtime_indexes = _get_conditionindexes(p, RuntimeStoppingCondition)
        for index in runtime_indexes
            p.stoppingconditions[index].limit = i
        end
    end
end
