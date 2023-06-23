using LinearAlgebra: norm

export RandomSearch

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
