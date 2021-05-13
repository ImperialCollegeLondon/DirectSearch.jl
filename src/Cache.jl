using JSON
using Unmarshal
using JLD2

export CacheLoadJSON, CacheSaveJSON, CacheLoadJLD2, CacheSaveJLD2
"""
    PointCache{T} <: AbstractCache

An abstract cache subtype that contains a dictionary of points/costs and a vector
that stores the order of incumbent points.
"""
mutable struct PointCache{T} <: AbstractCache
    #TODO: Record the type of point: incumbent, violates unrelaxable constraints,
    #violates relaxable constraints for iteration i, etc.

    #TODO: Set maximum cache size

    #TODO: An alternative data structure would be much faster

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

function CachePush(c::PointCache{T}, x::Vector{T}, cost::T) where T
    push!(c.costs, x=>cost)
end

#TODO add equivilent for infeasible
"""
    CacheOrderPush(p::AbstractProblem{T}) where T

Add the feasible incumbent point to the order vector.
"""
CacheOrderPush(p::AbstractProblem{T}) where T = CacheOrderPush(p.cache, p.x)
function CacheOrderPush(c::PointCache{T},
                        x::Union{Vector{T},Nothing},
                       ) where T
    x === nothing && return

    if length(c.order) == 0 || x != c.order[end]
        push!(c.order, x)
    end
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
(CacheRandomSample(c::PointCache{T}, n::Int)::Vector{Vector{T}}) where T =
    length(c.order) == 0 ? Vector{T}[] : rand(c.order, n)

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

CacheSaveJSON(p::AbstractProblem{T}, filename::String) where T = CacheSaveJSON(filename, p.cache)
function CacheSaveJSON(filename::String, c::PointCache{T}) where T
    open("$filename.json", "w") do file
        JSON.print(file, c.costs)
    end
end

CacheLoadJSON(p::AbstractProblem{T}, path::String) where T = CacheLoadJSON(path, p.cache, p.N)
function CacheLoadJSON(path::String, c::PointCache{T}, dim::Int) where T
    if isfile(path)
        json_contents = open("$path", "r") do file
            JSON.parse(file)
        end

        parsed_costs = Unmarshal.unmarshal(Dict{Vector{T},T}, json_contents)

        key_dim = length(first(keys(parsed_costs)))
        if key_dim !== dim
            error("Points of wrong dimension $(key_dim). Expected dimension: $dim ")
        end

        values_dim = length(first(values(parsed_costs)))
        if values_dim !== 1
            error("Costs of wrong dimension $values_dim. Expected dimension: 1")
        end

        c.costs = parsed_costs
    else
        error("File '$path' not found.")
    end
end

CacheSaveJLD2(p::AbstractProblem{T}, filename::String) where T = CacheSaveJLD2(filename, p.cache)
function CacheSaveJLD2(filename::String, c::PointCache{T}) where T
    jldopen("$filename.jld2", "w") do file
        file["cache_costs"] = c.costs
    end
end

CacheLoadJLD2(p::AbstractProblem{T}, path::String) where T = CacheLoadJLD2(path, p.cache, p.N)
function CacheLoadJLD2(path::String, c::PointCache{T}, dim::Int) where T
    if isfile(path)
        parsed_costs = jldopen("$path", "r") do file
            file["cache_costs"]
        end

        key_dim = length(first(keys(parsed_costs)))
        if key_dim !== dim
            error("Points of wrong dimension $(key_dim). Expected dimension: $dim ")
        end

        values_dim = length(first(values(parsed_costs)))
        if values_dim !== 1
            error("Costs of wrong dimension $values_dim. Expected dimension: 1")
        end

        c.costs = parsed_costs
    else
        error("File '$path' not found.")
    end
end
