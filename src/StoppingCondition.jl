export AddStoppingCondition, SetIterationLimit, BumpIterationLimit, SetFunctionEvaluationLimit,
       BumpFunctionEvaluationLimit, SetMinimumMeshSize, SetMinimumPollSize, RuntimeStoppingCondition


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


#Mesh size precision limit
mutable struct MeshPrecisionStoppingCondition{T} <: AbstractStoppingCondition
    cont_min_mesh_size::T
    min_mesh_sizes::Vector{T}

    function MeshPrecisionStoppingCondition{T}(min_mesh_size::Union{T, Nothing}=nothing) where T
        c = new()

        if min_mesh_size != nothing
            c.cont_min_mesh_size = min_mesh_size
        else
            c.cont_min_mesh_size = get_min_mesh_size(T)
        end

        return c
    end
end

function init_stoppingcondition(p::DSProblem, s::MeshPrecisionStoppingCondition)
    s.min_mesh_sizes = map(δ_min -> δ_min > 0 ? δ_min : s.cont_min_mesh_size, p.config.mesh.δ_min)
end

StoppingConditionStatus(::MeshPrecisionStoppingCondition) = "Mesh Precision limit"

function CheckStoppingCondition(p::DSProblem, s::MeshPrecisionStoppingCondition)
    if p.config.mesh.only_granular
        p.config.mesh.l > -50
    else
        any(GetMeshSizeVector(p) .> s.min_mesh_sizes)
    end
end


(GetMeshSizeVector(p::DSProblem{T})::Vector{T}) where T = p.config.mesh.δ

get_min_mesh_size(::Type{Float64}) = 1.1102230246251565e-16
get_min_mesh_size(::Type{T}) where T = eps(T)/2

"""
    SetMinimumMeshSize(p::DSProblem{T}, i::T) where T

Set the minimum poll size for continuous variables.
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

#Poll size precision limit
mutable struct PollPrecisionStoppingCondition{T} <: AbstractStoppingCondition
    cont_min_poll_size::T
    min_poll_sizes::Vector{T}

    function PollPrecisionStoppingCondition{T}(min_poll_size::Union{T, Nothing}=nothing) where T
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
