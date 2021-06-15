using LinearAlgebra: norm

export RandomSearch, NullSearch

"""
    Search(p::DSProblem{T})::IterationOutcome  where T

Generate search points and call evaluate on them.
"""
function Search(p::DSProblem{T})::IterationOutcome  where T
    p.status.search_time_total += @elapsed points = GenerateSearchPoints(p, p.config.search)
    p.full_output && OutputSearchStep(p, points)
    p.status.directions = nothing
    return EvaluatePoint!(p, points)
end


"""
    NullSearch()

Return no trial points for a search stage (ie, skips the
search stage from running)
"""
struct NullSearch <: AbstractSearch end

"""
    GenerateSearchPoints(p::DSProblem)

Search method that returns an empty vector.

Use when no search method is desired.
"""
(GenerateSearchPoints(p::DSProblem{T}, ::NullSearch)::Vector{Vector{T}}) where T = Vector{T}[]


"""
    GenerateSearchPoints(p::DSProblem{T})::Vector{Vector{T}} where T

Calls `GenerateSearchPoints` for the search step within `p`.
"""
(GenerateSearchPoints(p::DSProblem{T})::Vector{Vector{T}}) where T = GenerateSearchPoints(p, p.config.search)

"""
    RandomSearch(M::Int)

Return `M` randomly chosen trial points from the current mesh.
"""
mutable struct RandomSearch <: AbstractSearch
    M::Int #Number of points to generate
end

"""
    GenerateSearchPoints(p::DSProblem{T}, ::RandomSearch)::Vector{Vector{T}} where T

Finds points that are Δᵐ distance from any point in the mesh in a uniformly random direction.
"""
(GenerateSearchPoints(p::DSProblem{T}, s::RandomSearch)::Vector{Vector{T}}) where T =
                    RandomPointsFromCache(p.N, p.cache, p.config.mesh.δ, s)

function RandomPointsFromCache(N::Int, c::PointCache{T}, dist::Vector{T}, s::RandomSearch
                              )::Vector{Vector{T}} where T
    mesh_points = CacheRandomSample(c, s.M)

    if length(mesh_points) == s.M
        for i in 1:s.M
            dir = rand(N)
            dir .*= dist./norm(dir)
            mesh_points[i] += dir
        end
    end

    return mesh_points
end
