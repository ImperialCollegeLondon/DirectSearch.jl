export SetIterationLimit, BumpIterationLimit

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
