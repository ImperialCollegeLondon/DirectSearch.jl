export DefaultExtremeRef, DefaultProgressiveRef, AddExtremeConstraint, AddExtremeCollection,
       AddProgressiveCollection, AddProgressiveConstraint

"""
    @enum IterationOutcome

Has values Dominating, Improving, or Unsuccessful. Corresponding to the three
iteration outcomes in MADS-PB.
"""
@enum IterationOutcome begin
    Dominating
    Improving
    Unsuccessful
end

"""
    @enum ConstraintOutcome

Has the values `Feasible`, `WeakInfeasible`, or `StrongInfeasible` to classify
the outcome of the constraint evaluations of a single point.

A `Feasible` point meets the requirement of all constraints with no relaxation.

A `WeakInfeasible` outcome has at least one relaxable constraint violated
but no unrelaxable constraints violated.

A `StrongInfeasible` outcome indicates at least one unrelaxable constraint has
been violated or the relaxable constraint violation is reater than hmax.
"""
@enum ConstraintOutcome begin
    Feasible
    WeakInfeasible
    StrongInfeasible
end

"""
    CollectionIndex

An `Int` wrapper that is used for indexing constraint collections within a
`Constraints` object.
"""
struct CollectionIndex
    value::Int
end

"""
    CollectionIndex

An `Int` wrapper that is used for indexing constraints within a
`ConstraintCollection` object.
"""
struct ConstraintIndex
    value::Int
end

"""
    DefaultExtremeRef

The collection index that refers to the default location of extreme barrier
constraints.
"""
const DefaultExtremeRef = CollectionIndex(1)

"""
    DefaultProgressiveRef

The collection index that refers to the default location of progressive barrier
constraints.
"""
const DefaultProgressiveRef = CollectionIndex(2)


"""
    ConstraintCollection{FT,C}(h_max::FT,
                               h_max_update::Function,
                               aggregator::Function
                              ) where {FT<:AbstractFloat,C<:AbstractConstraint}

Contains multiple constraints of the same type that have the same settings
applied to them.

`h_max` is the initial hmax value.
`h_max_update` is a function that should update `h_max` given an
`IterationOutcome` value.
`aggregator` is a function that will bring all constraint violations of a
collection into a single `h` result.

Defaults for each of these values are set in the `AddProgressiveCollection` and
`AddExtremeCollection` functions.
"""
mutable struct ConstraintCollection{FT<:AbstractFloat, C<:AbstractConstraint}
    constraints::Vector{C}
    count::Int
    ignore::Bool
    h_max::FT
    result_aggregate::Function
    violation::FT

    function ConstraintCollection{FT, C}(h_max::FT, aggregator::Function
                                        ) where {FT<:AbstractFloat, C<:AbstractConstraint}
        c = new{FT, C}()
        c.constraints = []
        c.count = 0
        c.ignore = false
        c.h_max = h_max
        c.result_aggregate = aggregator
        c.violation = zero(FT)
        return c
    end
end

"""
    AbstractProgressiveConstraint <: AbstractConstraint

Parent type for progressive contraints.
"""
abstract type AbstractProgressiveConstraint <: AbstractConstraint end

"""
    ExtremeConstraint(f::Function)

Create an extreme barrier constraint. Function `f` should take a vector argument
and return `true` or `false` to indicate if the vector meets the constraint.
"""
mutable struct ExtremeConstraint <: AbstractConstraint
    f::Function
    ignore::Bool
    ExtremeConstraint(f::Function) = new(f, false)
end

"""
    ProgressiveConstraint(f::Function)

Create a progressive barrier constraint.

Argument `f` is a function that should take a single vector argument and
return a value that gives the amount the constraint function has been
violated.

A value greater than 0 indicates the function has been violated, 0 shows
that the input lies on the constraint, and negative numbers show a feasible
value.

Negative numbers may be truncated to 0 without affecting the algorithm.
"""
mutable struct ProgressiveConstraint <: AbstractProgressiveConstraint
    f::Function
    ignore::Bool
    ProgressiveConstraint(f::Function) = new(f, false)
end

"""
    ConstraintCache{FT<:AbstractFloat}

Store constraint information on an iteration-by-iteration basis.

Stores the final infeasible point hmax value of the previous iteration.
Also stores the collection hmax values computed for each point in an iteration.
"""
mutable struct ConstraintCache{FT<:AbstractFloat}
    OldHmax::FT
    hmax_map::Dict{Vector{FT}, Vector{FT}}

    function ConstraintCache{FT}() where {FT<:AbstractFloat}
        c = new{FT}()
        c.OldHmax = FT(Inf)
        c.hmax_map = Dict{Vector{FT}, Vector{FT}}()
        return c
    end
end

"""
    Constraints{FT<:AbstractFloat}()

Create an object that constains multiple `ConstraintCollection` objects and their
corresponding `ConstraintCache`.

Upon creation `Constraints` is automaticvally populated with two constraint
collections, an `ExtremeCollection` and a `ProgressiveCollection`.
"""
mutable struct Constraints{FT<:AbstractFloat}
    collections::Vector{ConstraintCollection}
    count::Int
    cache::ConstraintCache{FT}

    function Constraints{FT}() where {FT<:AbstractFloat}
        c = new{FT}()
        c.count = 0
        c.collections = []
        c.cache = ConstraintCache{FT}()

        AddExtremeCollection(c)
        AddProgressiveCollection(c)
        return c
    end
end

"""
    CollectionTypeCount(c::Constraints{T}, C::AbstractConstraint)::Int where T

Return the total number of constraints of type `C` that are stored in all collections.
"""
(CollectionTypeCount(c::Constraints{T}, C::AbstractConstraint)::Int) where T =
                sum([col.count for col in c.collections if typeof(col) ==
                     ConstraintCollection{T, C}])

"""
    ConstraintUpdate!(c::Constraints, result::IterationOutcome)

Perform all necessary actions required to update a problem's constraints
between iterations and clear the constraint cache.
"""
function UpdateConstraints(c::Constraints, h_max, result::IterationOutcome, feasible, infeasible)

    # Internal hmax should only be updated when the result is improving
    if result == Improving
        # hmax values per collection for the infeasible point's overall hmax value
        collections_hmax = c.cache.hmax_map[infeasible]

        # collection hmax values for all considered points
        all_points_hmax = values(c.cache.hmax_map)

        #Update internal hmax for each collection
        for (i, collection) in enumerate(c.collections)
            #The hmax value from the collection for each considered point
            hmax_set = [c[i] for c in all_points_hmax]

            if collections_hmax[i] == minimum(hmax_set)
                # if the infeasible point's hmax is minimum considered, then use that
                SetCollectionHmax(collection, collections_hmax[i])
            else
                # otherwise use the largest value less than the the infeasible point's
                SetCollectionHmax(collection, maximum(filter(x->x<collections_hmax[i], hmax_set)))
            end
        end
        SetOldHmax(c, h_max)
    end

    # Cache is only maintained over a single iteration
    ClearCache(c)
end


"""
    ConstraintCachePush(c::Constraints{T}, x::Vector{T}, i::Int, h::T) where T

For point `x` and constraint collection `i` push the violation function result
`h` to the cache.
"""
function ConstraintCachePush(p::AbstractProblem, x::Vector{T}, i::Int, h::T) where T
    if p.config.max_simultaneous_evaluations > 1
        lock(() -> constraint_cache_push(p.constraints, x, i, h), p.config.parallel_lock)
    else
        constraint_cache_push(p.constraints, x, i, h)
    end
end

function constraint_cache_push(c::Constraints{T}, x::Vector{T}, i::Int, h::T) where T
    if !haskey(c.cache.hmax_map, x)
        c.cache.hmax_map[x] = zeros(T, c.count)
    end
    c.cache.hmax_map[x][i] = h
end

function SetCollectionHmax(c::ConstraintCollection, new_hmax)
    c.h_max = new_hmax
end

function ClearCache(c::Constraints{T}) where T
    c.cache.hmax_map = Dict{Vector{T},Vector{T}}()
end

function SetOldHmax(c::Constraints{T}, hmax::T) where T
    c.cache.OldHmax = hmax
end

"""
    ConstraintEvaluation(constraints::Constraints{T}, p::Vector{T})::Tuple{ConstraintOutcome,T} where T

Evaluate point `p` over all constraint collections in `constraints`. Returns a
ConstraintOutcome indicating the result of the evaluation:

`Feasible`: `p` evaluated as feasible for all constraints (extreme and progressive barrier)

`WeakInfeasible`: `p` evaluated as feasible for all extreme barrier constraints, and had no
progressive barrier constraint violations greater than h_max

`StrongInfeasible`: At least one extreme barrier constraint evaluated as infeasible, or at least
one progressive barrier constraint had a violation greater than h_max

The second returned value is the sum of h_max values evaluated during the constraint checks.
"""
function ConstraintEvaluation(p::AbstractProblem, point::Vector{T})::ConstraintOutcome where T
    # Initially define result as feasible
    eval_result = Feasible
    for (i,collection) in enumerate(p.constraints.collections)
        collection.ignore && continue

        result = ConstraintCollectionEvaluation(p, collection, point)
        ConstraintCachePush(p, point, i, collection.violation)

        if result == WeakInfeasible
            eval_result = WeakInfeasible
        end

        # A single completely infeasible result (h(x) > 0 for extreme, or h(x) > h_max for prog) means invalid
        result == StrongInfeasible && return StrongInfeasible
    end

    return eval_result
end

"""
    GetViolationSum(c::Constraints, p::Vector{T})::T where T

Return the sum of all cached `h` values for point `p`.

If `p` hasn't been evaluated (which generally shouldn't happen) then
return ``\\infty``.
"""
(GetViolationSum(c::Constraints{T}, p::Vector{T})::T) where T =
                                            sum(get(c.cache.hmax_map, p, Inf))


(GetViolationSumParallel(p::AbstractProblem, point::Vector{T})::T) where T =
                                            lock(() -> GetViolationSum(p.constraints, point), p.config.parallel_lock)

(GetOldHmaxSum(c::Constraints{T})::T) where T = c.cache.OldHmax

function ConstraintCollectionEvaluation(p::AbstractProblem, collection::ConstraintCollection,
                                        x::Vector{FT})::ConstraintOutcome where {FT<:AbstractFloat}
    if p.config.max_simultaneous_evaluations > 1
        lock(() -> constraint_collection_evaluation(collection, x), p.config.parallel_lock)
    else
        constraint_collection_evaluation(collection, x)
    end
end

"""
    constraint_collection_evaluation(collection::ConstraintCollection{T,ProgressiveConstraint},
                                   x::Vector{T})::ConstraintOutcome where T

Evalute every constraint within progressive constraint collection `collection`
for point `x`.

If the aggregate value of the constraint evaluations exceeds the collection's
h_max then a `StrongInfeasible` is returned. If the value is less than or equal
to 0.0 then `Feasible` is returned. Otherwise `WeakInfeasible` is returned.
"""
function constraint_collection_evaluation(collection::ConstraintCollection{T,ProgressiveConstraint},
                                          x::Vector{T})::ConstraintOutcome where T
    sum = 0.0
    for c in collection.constraints
        c.ignore && continue
        sum += collection.result_aggregate(c.f(x))
    end
    collection.violation = sum
    if sum <= collection.h_max
        return sum == 0.0 ? Feasible : WeakInfeasible
    else
        return StrongInfeasible
    end
end

"""
    constraint_collection_evaluation(collection::ConstraintCollection{FT,ExtremeConstraint},
                                   x::Vector{FT})::ConstraintOutcome where {FT<:AbstractFloat}

Evalute every constraint within extreme constraint collection `collection` for
point `x`.

If any constraint returns false  or a value greater than 0 then a
`StrongInfeasible` result is returned. Otherwise a `Feasible` result is returned.
"""
function constraint_collection_evaluation(collection::ConstraintCollection{FT,ExtremeConstraint},
                                          x::Vector{FT})::ConstraintOutcome where {FT<:AbstractFloat}
    for c in collection.constraints
        c.ignore && continue
        v = c.f(x)
        v < zero(FT) || v == true || return StrongInfeasible
    end

    return Feasible
end



"""
    AddExtremeConstraint(p::AbstractProblem, c::Function
                         index::CollectionIndex=CollectionIndex(1)
                        )::ConstraintIndex where T

Register a single function that defines an extreme barrier constraint. Return
a constraint index.

The provided function should take a vector input and return a boolean or numeric
value indicating if the constraint has been met or not. `true` or less than or
equal to 0 indicates the constraint has been met. `false` or greater than 0
shows the constraint has been violated.

The `index` argument can be specified to give a collection to add the constraint
to. The specified collection must exist, and must be able to accept extreme
barrier constraints. If `index` is not specified then it is added to collection
1, the default extreme constraint collection.
"""
AddExtremeConstraint(p::AbstractProblem, f::Function; index::CollectionIndex=CollectionIndex(1)
                    ) = AddExtremeConstraint(p.constraints, f, index=index)

function AddExtremeConstraint(p::Constraints{T}, f::Function;
                              index::CollectionIndex=CollectionIndex(1))::ConstraintIndex where T
    i = index.value
    i < 0 && error("Collection indices must be positive")
    i > p.count && error("Invalid CollectionIndex")

    c = ExtremeConstraint(f)
    push!(p.collections[i].constraints, c)
    p.collections[i].count += 1
    return ConstraintIndex(p.collections[i].count)
end


"""
    AddExtremeConstraint(p::AbstractProblem, c::Vector{Function}; index::CollectionIndex=CollectionIndex(1))

Register a group of functions that define extreme barrier constraints. Calls
[`AddExtremeConstraint`](@ref) on each function individually.
"""
AddExtremeConstraint(p::AbstractProblem, f::Vector{Function}; index::CollectionIndex=CollectionIndex(1)
                    ) = AddExtremeConstraint(p.constraints, f, index=index)

function AddExtremeConstraint(p::Constraints, f::Vector{Function};
                              index::CollectionIndex=CollectionIndex(1))::Vector{ConstraintIndex}
    return [AddExtremeConstraint(p, fnc, index=index) for fnc in f]
end


"""
    AddProgressiveConstraint(p::AbstractProblem, c::Function; index::CollectionIndex=CollectionIndex(2))

Register a single function that defines a progressive barrier constraint. Return
an index that refers to the constraint.

The provided function should take a vector input and return a numeric value
indicating if the constraint has been met or not. Less than or
equal to 0 indicates the constraint has been met. 0 shows the constraint has
been violated.

The `index` argument can be specified to give a collection to add the constraint
to. The specified collection must exist, and must be able to accept progressive
barrier constraints. If `index` is not specified then it is added to collection
2, the default progressive barrier constraint collection.
"""
AddProgressiveConstraint(p::AbstractProblem, f::Function; index::CollectionIndex=CollectionIndex(2)
                        ) = AddProgressiveConstraint(p.constraints, f, index=index)

function AddProgressiveConstraint(p::Constraints, f::Function;
                                  index::CollectionIndex=CollectionIndex(2))::ConstraintIndex
    i = index.value
    i < 0 && error("Collection indices must be positive")
    i > p.count && error("Invalid CollectionIndex")

    c = ProgressiveConstraint(f)
    push!(p.collections[i].constraints, c)
    p.collections[i].count += 1
    return ConstraintIndex(p.collections[i].count)
end


"""
    AddProgressiveConstraint(p::AbstractProblem, c::Vector{Function})::Vector{Int}

Register a group of functions that define progressive barrier constraints. Calls
[`AddProgressiveConstraint`](@ref) on each function individually.
"""
AddProgressiveConstraint(p::AbstractProblem, f::Vector{Function}; index::CollectionIndex=CollectionIndex(2)
                        ) = AddProgressiveConstraint(p.constraints, f, index=index)

function AddProgressiveConstraint(p::Constraints, c::Vector{Function};
                                  index::CollectionIndex=CollectionIndex(2))::Vector{ConstraintIndex}
    return map(f -> AddProgressiveConstraint(p, f, index=index), c)
end

"""
    AddProgressiveCollection(p::Constraints{FT}; h_max=Inf, h_max_update::Function=h_max_update,
                             aggregator::Function=x->max(0,x)^2)::CollectionIndex where {FT<:AbstractFloat}

Instantiate a new constraint collection within the problem. Returns an index that refers to this
new collection.

The default constraint settings match those from Audet & Dennis 2009:

`h_max`: Begins as infinity

`h_max_update`: Sets h_max to the largest valid h evaluation if an iteration is improving

`aggregator`: Creates h as ``\\sum k(x)`` where ``k=\\max(0,x)^2``
"""
AddProgressiveCollection(p::AbstractProblem; kwargs...)::CollectionIndex = AddProgressiveCollection(p.constraints; kwargs...)

function AddProgressiveCollection(p::Constraints{FT}; h_max=FT(Inf),
                                  aggregator::Function=x->max(0,x)^2)::CollectionIndex where {FT<:AbstractFloat}
    push!(p.collections,
          ConstraintCollection{FT,ProgressiveConstraint}(h_max, aggregator))
    p.count += 1

    return CollectionIndex(p.count)
end


"""
    AddExtremeCollection(p::Constraints{FT})::CollectionIndex where {FT<:AbstractFloat}

Instantiate a new constraint collection for extreme constraints. Returns an index that
refers to the new collection.
"""
(AddExtremeCollection(p::AbstractProblem)::CollectionIndex) = AddExtremeCollection(p.constraints)

function AddExtremeCollection(p::Constraints{FT})::CollectionIndex where {FT<:AbstractFloat}
    f() = error("Should not be calling aggregator update for an extreme constraint collection")
    push!(p.collections, ConstraintCollection{FT,ExtremeConstraint}(zero(FT), f))
    p.count += 1
    return CollectionIndex(p.count)
end

#DisableConstraint(p::AbstractProblem, constraint_index::ConstraintIndex;
#                  collection_index::CollectionIndex = CollectionIndex(
#                 ) = DisableConstraint(p.constraints, i)
#function DisableConstraint(c::Constraints, i::Int)
#    i > c.count && error("Invalid constraint index, largest known index is $(c.count)")
#    c.constraints[i].ignore == true
#end
#
#EnableConstraint(p::AbstractProblem, i::Int) = EnableConstraint(p.constraints, i)
#function EnableConstraint(c::ConstraintCollection, i::Int)
#    i > c.count && error("Invalid constraint index, largest known index is $(c.count)")
#    c.constraints[i].ignore == false
#end
