using LinearAlgebra: norm 

export RandomSearch, NullSearch

function Search(p::DSProblem{T})::IterationOutcome  where T
    points = GenerateSearchPoints(p, p.search)
    return EvaluatePoint!(p, points)
end


mutable struct NullSearch <: AbstractSearch end

"""
    GenerateSearchPoints(p::DSProblem)

Search method that returns an empty vector.

Use when no search method is desired.
"""
GenerateSearchPoints(p::DSProblem, ::NullSearch) = []


"""
    GenerateSearchPoints(p::DSProblem{T})::Vector{Vector{T}} where T

Alias for GenerateSearchPoints(p, NullSearch).
"""
GenerateSearchPoints(p::DSProblem) = GenerateSearchPoints(p, NullSearch())

mutable struct RandomSearch <: AbstractSearch
    M::Int #Number of points to generate
end

"""
    GenerateSearchPoints(p::DSProblem{T}, ::RandomSearch)::Vector{Vector{T}} where T

Finds points that are Δᵐ distance from any point in the mesh in a uniformly random direction.
"""
function GenerateSearchPoints(p::DSProblem{T}, s::RandomSearch
                             )::Vector{Vector{T}} where T
    #TODO generate directions from the D mesh matrix
    return CacheRandomPoints(p.N, p.cache, p.mesh.Δᵐ, s)
end

function CacheRandomPoints(N::Int, c::PointCache{T}, dist::T, s::RandomSearch
                             )::Vector{Vector{T}} where T
    mesh_points = CacheRandomSample(c, s.M)     

    for i in 1:s.M
        dir = rand(N)
        dir *= dist/norm(dir)
        mesh_points[i] += dir
    end

    return mesh_points
end

