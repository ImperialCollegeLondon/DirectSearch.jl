export AddStoppingCondition, RuntimeStoppingCondition


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

    if typeof(s) == IterationStoppingCondition
        p.status.optimization_status = IterationLimit
    elseif typeof(s) == MeshPrecisionStoppingCondition
        p.status.optimization_status = PrecisionLimit
    elseif typeof(s) == FunctionEvaluationStoppingCondition
        p.status.optimization_status = FunctionEvaluationLimit
    elseif typeof(s) == RuntimeStoppingCondition
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

#===== Optional stopping conditions =====#

#Runtime limit
mutable struct RuntimeStoppingCondition <: AbstractStoppingCondition
    limit::Float64
end

StoppingConditionStatus(::RuntimeStoppingCondition) = "Runtime limit"

CheckStoppingCondition(p::DSProblem, s::RuntimeStoppingCondition) = (time() - p.status.start_time) < s.limit

function init_stoppingcondition(::DSProblem, s::RuntimeStoppingCondition) #TODO: check this
    if s.limit == -1
        error("Please set a runtime limit")
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
