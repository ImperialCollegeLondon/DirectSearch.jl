#=

File defines the abstract types used within the package.

=#
export SetObjective

abstract type AbstractProblem{T} end

"""
    abstract type AbstractPollDirectionGenerator end

Parent type for any type used for implementing a direction generator.

Generally any direction generators should return vectors with unit length of
one

"""
abstract type AbstractPoll end

abstract type AbstractSearch end

"""
    abstract type AbstractMesh end

Parent type of any struct implementing the construction of a mesh. To maintain
compatibility with other aspects of the package, the naming convention for
variables within structs must be followed. These respect the notation used
within Audet & Dennis 2006.
"""
abstract type AbstractMesh end

abstract type AbstractConstraint end

abstract type AbstractCache end

abstract type AbstractStoppingCondition end

@enum ProblemSense Min Max

@enum OptimizationStatus Unoptimized MeshPrecisionLimit PollPrecisionLimit IterationLimit FunctionEvaluationLimit RuntimeLimit OtherStoppingCondition

"""
    Config(;sense::ProblemSense=Min,
            opportunistic::Bool=false,
            kwargs...
          )

Encapsulates configuration options for the solver, generally shouldn't
be user-edited.

Generally these are set at the start (automatically or via setter functions)
and don't change.
"""
mutable struct Config{FT<:AbstractFloat, MT<:AbstractMesh, ST<:AbstractSearch, PT<:AbstractPoll}

    poll::PT
    search::ST

    mesh::MT
    meshscale::Vector{FT}

    num_procs::Int
    max_simultanious_evaluations::Int
    opportunistic::Bool

    function Config{FT}(N::Int,
                        poll::AbstractPoll,
                        search::AbstractSearch,
                        mesh::AbstractMesh=Mesh{FT}(N);
                        opportunistic::Bool=false,
                        kwargs...
                       ) where {FT<:AbstractFloat}
        c = new{FT, typeof(mesh), typeof(search), typeof(poll)}()

        c.poll = poll
        c.search = search

        c.mesh = mesh
        c.meshscale = ones(N)

        c.num_procs = nworkers()
        c.max_simultanious_evaluations = 1
        c.opportunistic = opportunistic

        return c
    end
end

mutable struct Status{T}
    function_evaluations::Int64
    cache_hits::Int64
    iteration::Int64
    directions::Vector{Vector{T}}
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
        s.directions = Vector{Vector{T}}()
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

