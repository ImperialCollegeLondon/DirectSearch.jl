mutable struct PointCache{T} <: AbstractCache
    #TODO: Record the type of point: incumbent, violates unrelaxable constraints,
    #violates relaxable constraints for iteration i, etc.
    
    #TODO: Set maximum cache size

    #TODO: (maybe) Implement more efficient storage/search strategy
    
    #Map a point to a cost value
    costs::Dict{Vector{T},T} 
    #List the incumbent points in the order they are considered
    order::Vector{Vector{T}} 

    function PointCache{T}() where T
        c = new()
        c.costs = Dict{Vector{T},T}()
        c.order = Vector{Vector{T}}()
        return c
    end
end

"""
    CachePush(p::AbstractProblem, x::Vector, cost)

Add point `x` and its cost `cost` to the cache of `p`. 
"""
CachePush(p::AbstractProblem{T}, x::Vector{T}, cost::T) where T = CachePush(p.cache, x, cost)

"""
    CachePush(p::AbstractProblem)

Add the feasible and infeasible incumbent points (assuming neither are `nothing`)
to the cache.
"""
function CachePush(p::AbstractProblem)
    p.x != nothing && CachePush(p.cache, p.x, p.x_cost)
    p.i != nothing && CachePush(p.cache, p.i, p.i_cost)
end



#TODO order should be changed as it does not necessarily reflected order of incumbent,
#only the other that points are evaluated
function CachePush(c::PointCache{T}, x::Vector{T}, cost::T) where T
    push!(c.costs, x=>cost)
    push!(c.order, x)
end

"""
    CacheQuery(p::AbstractProblem, x::Vector)

Query the cache of `p` to find if it has a cost value for point `x`. Alias 
to `haskey`.
"""
CacheQuery(p::AbstractProblem, x::Vector) = CacheQuery(p.cache, x)
CacheQuery(c::PointCache{T}, x::Vector{T}) where T = haskey(c.costs, x)

"""
    CacheGet(p::AbstractProblem, x::Vector)

Return the cost of point `x` in the cache of `p`. Does not check if 
`x` is in the cache, use `CacheQuery` to check.
"""
CacheGet(p::AbstractProblem, x::Vector) = CacheGet(p.cache, x)
(CacheGet(c::PointCache{T}, x::Vector{T})::T) where T = c.costs[x]

"""
    CacheRandomSample(p::AbstractProblem, n::Int)

Returns a uniformly sampled collection of `n` points from the cache. Points 
can be repeated in the sample.
"""
CacheRandomSample(p::AbstractProblem, n::Int) = CacheRandomSample(p.cache, n)
(CacheRandomSample(c::PointCache{T}, n::Int)::Vector{Vector{T}}) where T = rand(c.order, n)

"""
    CacheInitialPoint(p::AbstractProblem)

Return a tuple of the initial point added to the cache and its cost.
"""
CacheInitialPoint(p::AbstractProblem) = CacheInitialPoint(p.cache)
(CacheInitialPoint(c::PointCache{T})::Tuple{Vector,T}) where T = (c.order[1], c.costs[c.order[1]])

"""
    CacheGetRange(p::AbstractProblem, points::Vector)::Vector{Vector}

Return a vector of costs corresponding to the vector of points.
"""
CacheGetRange(p::AbstractProblem, points::Vector)::Vector = CacheGetRange(p.cache, points)
CacheGetRange(c::PointCache{T}, points::Vector) where T =
              CacheGetRange(c, convert(Vector{Vector{T}}, points))
(CacheGetRange(c::PointCache, points::Vector{Vector{T}})::Vector{T}) where T = map(p->CacheGet(c,p), points)

"""
    CacheFilter(p::AbstractProblem{T}, points::Vector{T})::Tuple{Vector{Vector{T}},Vector{Vector{T}}} where T

Return a tuple where the first entry is the set of input points in the cache and the
second is the set of input points not in the cache.
"""
(CacheFilter(p::AbstractProblem{T}, points
            )::Tuple{Vector{Vector{T}},Vector{Vector{T}}}) where T =
            CacheFilter(p.cache, convert(Vector{Vector{T}}, points))

(CacheFilter(p::PointCache{T}, points
            )::Tuple{Vector{Vector{T}},Vector{Vector{T}}}) where T =
            CacheFilter(p, convert(Vector{Vector{T}}, points))

function CacheFilter(c::PointCache{T}, points::Vector{Vector{T}}
                    )::Tuple{Vector{Vector{T}},Vector{Vector{T}}} where T
    qt = p -> CacheQuery(c, p)
    qf = p -> !CacheQuery(c, p)
    return filter(qt, points),filter(qf, points)
end
                    
