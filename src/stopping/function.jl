export SetFunctionEvaluationLimit, BumpFunctionEvaluationLimit

#Function evaluation limit
mutable struct FunctionEvaluationStoppingCondition <: AbstractStoppingCondition
    limit::Int64
end

StoppingConditionStatus(::FunctionEvaluationStoppingCondition) = "Function evaluation limit"

CheckStoppingCondition(p::DSProblem, s::FunctionEvaluationStoppingCondition) = p.status.function_evaluations < s.limit

function init_stoppingcondition(::DSProblem, s::FunctionEvaluationStoppingCondition)
    if s.limit == -1 
        error("Please set a maximum number of function evaluations")
    end
end

"""
    SetFunctionEvaluationLimit(p::DSProblem, i::Int)

Set the maximum number of function evaluations to `i`.
"""
function SetFunctionEvaluationLimit(p::DSProblem, i::Int)
    if i < p.status.function_evaluations
        error("Cannot set function evaluation limit to lower than the number of function evaluations that have run")
    else
        function_evaluation_indexes = _get_conditionindexes(p, FunctionEvaluationStoppingCondition)
        for index in function_evaluation_indexes
            p.stoppingconditions[index].limit = i
        end
    end
end

"""
    BumpFunctionEvaluationLimit(p::DSProblem, i::Int)

Increase the function evaluation limit by `i`.
"""
function BumpFunctionEvaluationLimit(p::DSProblem, i::Int)
    function_evaluation_indexes = _get_conditionindexes(p, FunctionEvaluationStoppingCondition)
    for index in function_evaluation_indexes
        p.stoppingconditions[index].limit += i
    end
end
