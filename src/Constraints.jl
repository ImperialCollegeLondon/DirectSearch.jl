export DefaultExtremeRef, DefaultProgressiveRef, AddExtremeConstraint, AddExtremeCollection,
       AddProgressiveCollection, AddProgressiveConstraint

"""
    @enum IterationOutcome

Has values Dominating, Improving, or Unsuccessful. Corresponding to the three iteration outcomes in
progressive barrier direct search algorithms.
"""
@enum IterationOutcome begin
    Dominating
    Improving
    Unsuccessful
end

"""
    @enum ConstraintOutcome

Has the values `Feasible`, `WeakInfeasible`, or `StrongInfeasible` to classify the outcome of the 
constraint evaluations of a point. A `Feasible` point meets the requirement of all constraints
with no relaxation. A `WeakInfeasible` outcome requires one or more constraints to be relaxed, but less than
their maximum amount. A `StrongInfeasible` outcome indicates one or more constraints was violated beyond its
maximum relaxation amount.
"""
@enum ConstraintOutcome begin
    Feasible
    WeakInfeasible
    StrongInfeasible
end

"""
    CollectionIndex

An `Int` wrapper that is used for indexing constraint collections within a `Constraints` object.
"""
struct CollectionIndex
    value::Int
end

"""
    CollectionIndex

An `Int` wrapper that is used for indexing constraints within a `ConstraintCollection` object.
"""
struct ConstraintIndex
    value::Int
end

"""
    DefaultExtremeRef
    
The collection index that refers to the default location of extreme barrier constraints.
"""
const DefaultExtremeRef = CollectionIndex(1)

"""
    DefaultProgressiveRef
    
The collection index that refers to the default location of progressive barrier constraints.
"""
const DefaultProgressiveRef = CollectionIndex(2)


"""
    ConstraintCollection{T,C}(h_max::T, h_max_update::Function, aggregator::Function) where {T,C<:AbstractConstraint}

Contains multiple constraints of the same type that have the same settings applied to them.

`h_max` is the initial hmax value. `h_max_update` is a function that should update `h_max` given
an `IterationOutcome` value. `aggregator` is a function that will bring all constraint violations of a collection
into a single `h` result.

Defaults for each of these values is set in the `AddProgressiveCollection` and `AddExtremeCollection` functions.
"""
mutable struct ConstraintCollection{T,C<:AbstractConstraint}
    constraints::Vector{C}
    count::Int
    ignore::Bool
    h_max::T
    h_max_store::Vector{T}
    h_max_update::Function
    result_aggregate::Function
    function ConstraintCollection{T,C}(h_max::T, h_max_update::Function, aggregator::Function
                                      ) where {T,C<:AbstractConstraint} 
        c = new()
        c.constraints = []
        c.count = 0
        c.ignore = false
        c.h_max = h_max
        c.h_max_store = []
        c.h_max_update = h_max_update
        c.result_aggregate = aggregator
        return c
    end
end   

"""
    h_max_update(c::ConstraintCollection, result::IterationOutcome)

Update h_max according to the LTMADS default in eqn 2.5, Audet & Dennis 2009
"""
function h_max_update(c::ConstraintCollection, result::IterationOutcome)
    if result == Improving
        h_maxes = filter(h->h<c.h_max, c.h_max_store)
        isempty(h_maxes) && return
        c.h_max = max(h_maxes...)
    end
    #Otherwise h_max remains as it was
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

Create a progressive barrier constraint. Function `f` should take a vector argument 
and return a value in the range 0<=v<Inf to indicate the amount the constraint has
been violated by the input vector. If input is a feasible point then the constraint 
function should return zero. 
"""
mutable struct ProgressiveConstraint <: AbstractProgressiveConstraint
    f::Function
    ignore::Bool
    ProgressiveConstraint(f::Function) = new(f, false)
end

"""
    Constraints{T}() where T

Create an object that constains multiple constraint collection objects.

Upon creation `Constraints` is automativally populated with two constraint collections,
an `ExtremeCollection` and a `ProgressiveCollection`.
"""
mutable struct Constraints{T}
    collections::Vector{ConstraintCollection}
    count::Int
    function Constraints{T}() where T
        c = new()
        c.count = 0
        c.collections = []
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

ConstraintUpdate!(p::AbstractProblem, result::IterationOutcome) = ConstraintUpdate!(p.constraints, result)

"""
    ConstraintUpdate!(c::Constraints, result::IterationOutcome)

Perform all necessary actions required to update a problem's constraints
between iterations. 

Currently will call `h_max_update` on each constraint.
"""
function ConstraintUpdate!(c::Constraints, result::IterationOutcome)
    for collection in c.collections
        h_max_update(collection, result)
    end
end

"""
    ConstraintEvaluation(constraints::Constraints{T}, x::Vector{T})::Tuple{ConstraintOutcome,T} where T

Evaluate point `x` over all constraint collections in `constraints`. Returns a 
ConstraintOutcome indicating the result of the evaluation:

`Feasible`: `x` evaluated as feasible for all constraints (extreme and progressive barrier)

`WeakInfeasible`: `x` evaluated as feasible for all extreme barrier constraints, and had no 
progressive barrier constraint violations greater than h_max

`StrongInfeasible`: At least one extreme barrier constraint evaluated as infeasible, or at least
one progressive barrier constraint had a violation greater than h_max

The second returned value is the sum of h_max values evaluated during the constraint checks.
"""
function ConstraintEvaluation(constraints::Constraints{T}, x::Vector{T})::Tuple{ConstraintOutcome,T}where T
    # Initially define result as feasible
    eval_result = Feasible
    for collection in constraints.collections
        collection.ignore && continue
        eval_result = ConstraintCollectionEvaluation(collection, x) 
        # A single completely infeasible result (h(x) > 0 for extreme, or h(x) > h_max for prog) means invalid
        eval_result == StrongInfeasible && return StrongInfeasible, convert(T,0.0)
    end
    return eval_result, sum([isempty(p.h_max_store) ? 0 : p.h_max_store[end] for p in constraints.collections])
end

"""
    GetHmaxSum(c::Constraints)

Return the sum of all `h_max` values for each collection in `c`.
"""
GetHmaxSum(c::Constraints) = sum([p.h_max for p in c.collections])

"""
    ConstraintCollectionEvaluation(collection::ConstraintCollection{T,ProgressiveConstraint}, x::Vector{T})::ConstraintOutcome where T
                               

Evalute every constraint within progressive constraint collection `collection` for point `x`.

If the aggregate value of the constraint evaluations exceeds h_max then a `StrongInfeasible` is 
returned. If the value is 0.0 then `Feasible` is returned. Otherwise `WeakInfeasible` is returned.
"""
function ConstraintCollectionEvaluation(collection::ConstraintCollection{T,ProgressiveConstraint},
                                        x::Vector{T})::ConstraintOutcome where T
    sum = 0.0
    for c in collection.constraints
        c.ignore && continue
        sum += collection.result_aggregate(c.f(x))
    end
    push!(collection.h_max_store, sum)
    if sum <= collection.h_max 
        return sum == 0.0 ? Feasible : WeakInfeasible
    else 
        return StrongInfeasible
    end
end

"""
ConstraintCollectionEvaluation(collection::ConstraintCollection{T,ExtremeConstraint}, x::Vector{T})::ConstraintOutcome where T

Evalute every constraint within extreme constraint collection `collection` for point `x`.

If any constraint returns false then a `StrongInfeasible` result is returned. Otherwise a 
`Feasible` result is returned.
"""
function ConstraintCollectionEvaluation(collection::ConstraintCollection{T,ExtremeConstraint}, 
                                        x::Vector{T})::ConstraintOutcome where T
    for c in collection.constraints
        c.ignore && continue
        v = c.f(x)
        v < convert(T,0.0) || v == true || return StrongInfeasible
    end

    return Feasible
end



"""
    AddExtremeConstraint(p::AbstractProblem, c::Function)::Tuple(ConstraintIndex, CollectionIndex)

Register a single function that defines an extreme barrier constraint. Return
a constraint index.

The provided function should take a vector input and return a boolean value 
indicating if the constraint has been met or not.

The `index` argument can be specified to give a collection to add the constraint to. The specified
collection must exist, and must be able to accept extreme barrier constraints.
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

The provided function should take a vector input and return a violation amount. The
return type should be the same as the type that the problem is defined as (default 
is `Float64`).
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
    AddProgressiveCollection(p::Constraints{T}; h_max=Inf, h_max_update::Function=h_max_update, 
                             aggregator::Function=x->max(0,x)^2)::CollectionIndex where T

Instantiate a new constraint collection within the problem. Returns an index that refers to this
new collection.

The default constraint settings match those from Audet & Dennis 2009:

`h_max`: Begins as infinity

`h_max_update`: Sets h_max to the largest valid h evaluation if an iteration is improving

`aggregator`: Creates h as ∑k(x) where k=max(0,x)^2

Note that the aggregator differs from that proposed by Audet & Dennis 2009 due to supporting
multiple values of h_max at the same time.
"""
AddProgressiveCollection(p::AbstractProblem; kwargs...)::CollectionIndex = AddProgressiveCollection(p.constraints; kwargs...)

function AddProgressiveCollection(p::Constraints{T}; h_max=Inf, 
                                  h_max_update::Function=h_max_update, 
                                  aggregator::Function=x->max(0,x)^2)::CollectionIndex where T
    push!(p.collections,
          ConstraintCollection{T,ProgressiveConstraint}(h_max, h_max_update, aggregator))
    p.count += 1

    return CollectionIndex(p.count)
end


"""
    AddExtremeCollection(p::Constraints{T})::CollectionIndex where T

Instantiate a new constraint collection for extreme constraints. Returns an index that 
refers to the new collection.
"""
(AddExtremeCollection(p::AbstractProblem)::CollectionIndex) where T = 
    AddExtremeCollection(p.constraints)

function AddExtremeCollection(p::Constraints{T})::CollectionIndex where T
    f1() = error("Should not be calling h_max update for an extreme constraint collection")
    f2() = error("Should not be calling aggregator update for an extreme constraint collection")
    push!(p.collections, ConstraintCollection{T,ExtremeConstraint}(0.0, f1, f2))
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
