#=

File defines the abstract types used within the package.

=#

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


