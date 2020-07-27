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
    Config()

Encapsulates configuration options for the solver, generally shouldn't
be user-edited.
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
