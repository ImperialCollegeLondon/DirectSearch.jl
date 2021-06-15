#=

File defines the abstract types used within the package.

=#

abstract type AbstractProblem{T} end

abstract type AbstractPoll end

abstract type AbstractSearch end

"""
    abstract type AbstractMesh end

Parent type of any struct implementing the construction of a mesh. To maintain
compatibility with other aspects of the package, the naming convention for
variables within structs must be followed. These respect the notation used
within Audet, Le Digabel & Tribes 2019.
"""
abstract type AbstractMesh end

abstract type AbstractConstraint end

"""
    abstract type AbstractCache end

Parent type of any struct implementing the cache.
"""
abstract type AbstractCache end

"""
    abstract type AbstractStoppingCondition end

Parent type of any struct implementing a stopping condition.
"""
abstract type AbstractStoppingCondition end

@enum ProblemSense Min Max

@enum OptimizationStatus Unoptimized MeshPrecisionLimit PollPrecisionLimit IterationLimit FunctionEvaluationLimit RuntimeLimit OtherStoppingCondition

"""
    Config{FT}(N::Int,
           poll::AbstractPoll,
           search::AbstractSearch,
           mesh::AbstractMesh=Mesh{FT}(N);
           opportunistic::Bool=false,
           cost_digits::Int=32,
           kwargs...
           ) where {FT<:AbstractFloat}

Encapsulates configuration options for the solver, generally shouldn't
be user-edited.

Generally these are set at the start (automatically or via setter functions)
and don't change.
"""
mutable struct Config{FT<:AbstractFloat, MT<:AbstractMesh, ST<:AbstractSearch, PT<:AbstractPoll}

    poll::PT
    search::ST

    mesh::MT

    num_threads::Int
    max_simultaneous_evaluations::Int
    parallel_lock::Threads.AbstractLock
    opportunistic::Bool

    cost_digits::Int

    function Config{FT}(N::Int,
                        poll::AbstractPoll,
                        search::AbstractSearch,
                        mesh::AbstractMesh=Mesh{FT}(N);
                        opportunistic::Bool=false,
                        cost_digits::Int=32,
                        kwargs...
                       ) where {FT<:AbstractFloat}
        c = new{FT, typeof(mesh), typeof(search), typeof(poll)}()

        c.poll = poll
        c.search = search

        c.mesh = mesh

        c.num_threads = Threads.nthreads()
        c.max_simultaneous_evaluations = 1
        c.opportunistic = opportunistic

        c.cost_digits = cost_digits

        return c
    end
end

"""
    Status{T}() where T

Holds the status information of the solver.
"""
mutable struct Status{T}
    function_evaluations::Int64
    cache_hits::Int64
    iteration::Int64
    directions::Union{Vector{Vector{T}}, Nothing}
    success_direction::Union{Vector{T},Nothing}

    optimization_status::OptimizationStatus
    optimization_status_string::String

    #= Time Running Totals =#
    runtime_total::Float64
    search_time_total::Float64
    poll_time_total::Float64
    blackbox_time_total::Float64

    #= Start/End Time =#
    start_time::Float64
    end_time::Float64

    function Status{T}() where T
        s = new()

        s.function_evaluations = 0
        s.iteration = 0
        s.cache_hits = 0
        s.directions = nothing
        s.success_direction = nothing
        s.optimization_status_string = "Unoptimized"
        s.optimization_status = Unoptimized

        s.runtime_total = 0.0
        s.search_time_total = 0.0
        s.poll_time_total = 0.0
        s.blackbox_time_total = 0.0

        return s
    end
end

