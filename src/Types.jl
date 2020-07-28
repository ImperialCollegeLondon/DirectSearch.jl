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


@enum ProblemSense Min Max
@enum OptimizationStatus Unoptimized PrecisionLimit IterationLimit

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
mutable struct Config 
    num_procs::Int 
    max_simultanious_evaluations::Int
    opportunistic::Bool
    sense::ProblemSense
                          
    function Config(;sense::ProblemSense=Min,
                     opportunistic::Bool=false, 
                     kwargs...
                    )
        c = new()
        c.num_procs = nworkers()
        c.max_simultanious_evaluations = 1
        c.sense=sense
        c.opportunistic = opportunistic

        return c
    end
end

mutable struct Status{T}
    function_evaluations::Int
    iteration::Int
    optimization_status::OptimizationStatus
    
    #= Time Running Totals =#
    #overall solve time
    runtime_total::T
    #time spent in search
    search_time_total::T
    #time spent in poll
    poll_time_total::T
    #time spent in function eval
    blackbox_time_total::T

    #= Start Time =#
    start_time::T

    function Status{T}() where T
        s = new()

        s.function_evaluations = 0
        s.iteration = 0
        s.optimization_status = Unoptimized

        return s
    end

end
