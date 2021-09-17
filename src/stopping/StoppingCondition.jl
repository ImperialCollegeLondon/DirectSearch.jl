export AddStoppingCondition

"""
    AddStoppingCondition(p::DSProblem, c::T) where T <: AbstractStoppingCondition
   
Add the stopping condition `c` to the problem `p`.
"""
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
    p.status.optimization_status_string = StoppingConditionStatus(s)

    if s isa IterationStoppingCondition
        p.status.optimization_status = IterationLimit
    elseif s isa MeshPrecisionStoppingCondition
        p.status.optimization_status = MeshPrecisionLimit
    elseif s isa PollPrecisionStoppingCondition
        p.status.optimization_status = PollPrecisionLimit
    elseif s isa FunctionEvaluationStoppingCondition
        p.status.optimization_status = FunctionEvaluationLimit
    elseif s isa RuntimeStoppingCondition
        p.status.optimization_status = RuntimeLimit
    else
        p.status.optimization_status = OtherStoppingCondition
    end
end

StoppingConditionStatus(::T) where T <: AbstractStoppingCondition = "Unknown stopping condition status"

function _init_stoppingconditions(p::DSProblem)
    for c in p.stoppingconditions
        init_stoppingcondition(p, c)
    end
end

init_stoppingcondition(::DSProblem, ::AbstractStoppingCondition) = nothing

_get_conditionindexes(p::DSProblem, target::Type) = _get_conditionindexes(p.stoppingconditions, target)
_get_conditionindexes(s::Vector{AbstractStoppingCondition}, target::Type) = 
    [i for (i,v) in enumerate(s) if typeof(v) == target]
