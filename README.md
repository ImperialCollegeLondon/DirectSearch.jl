# DirectSearch.jl
<!-- Currently isn't a stable release -->
<!--[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/stable)-->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/dev)
[![Build Status](https://travis-ci.com/EdwardStables/DirectSearch.jl.svg?branch=master)](https://travis-ci.com/EdwardStables/DirectSearch.jl)

*This is a temporary mirror of the [main project repo](https://github.com/ImperialCollegeLondon/DirectSearch.jl), development will move back there in mid-May*

DirectSearch.jl provides a framework for the implementation of algorithms in the MADS family. These are derivative free, black box algorithms, meaning that no analytical knowledge of the objective function or any constraints are needed. This package provides the core MADS algorithms (LTMADS, progressive and extreme barrier constraints, OrthoMADS (in future)), as well as supporting custom algorithms.

## Installation

This package is not yet registered. Install with:
```julia
pkg> add https://github.com/EdwardStables/DirectSearch.jl
```
And import as with any Julia package:
```julia
using DirectSearch
```

## Basic Usage
The core data structure is the `DSProblem` type. At a minimum it requires the dimension of the problem:
```julia
p = DSProblem(3);
```
The objective function, initial point, and other parameters may be specified in `DSProblem`:
```julia
obj(x) = x'*[2 1;1 4]*x + x'*[1;4] + 7;
p = DSProblem(2; objective=obj, initial_point=[1.0,2.0]);
```
Note that the objective function is assumed to take a single array of points of points as the input, and return a scalar cost. The initial point should be an array of the same dimensions of the problem, and feasible with respect to any extreme barrier constraints. See `DSProblem`'s documentation for a full list of parameters.

Parameters can also be set after generation of the problem:
```julia
p = DSProblem(2);
SetInitialPoint(p, [1.0,2.0]);
SetObjective(p,obj);
SetIterationLimit(p, 500);
```

Run the algorithm with `Optimize!`.
```julia
Optimize!(p);
```
This will run MADS until either the iteration limit (default 1000), or precision limit (`Float64` precision) are reached. The reason for stopping can be accessed as the `status` variable within the problem.
```julia
@show p.status
> p.status = DirectSearch.PrecisionLimit
```
The results can also be found in a similar manner:
```julia
@show p.x
> p.x = [0.0, -0.5]
@show p.x_cost
> p.x_cost = 6.0
```
Functions for accessing this data will be added in future.

By default, `DSProblem` is parameterised as `Float64`, but this can be overridden:
```julia
p = DSProblem{Float32}(3);
```
However, this is mostly untested and will almost certainly break. It is included to allow future customisation to be less painful.

## Constraints
Two kinds of constraints are included, progressive barrier, and extreme barrier constraints. As with the objective function, these should be specified as a Julia function that takes a point, and returns a value. 

Extreme barrier constraints are constraints that cannot be violated, and their function can return boolean (true for a valid point, false for invalid), or a numerical value that gives the violation amount (0 meaning the point is on the constraint boundary, >0 for violation, <0 for within the feasible region). This second option is to give compatibility with progressive barrier constraints. Added via `AddExtremeConstraint`:

```julia
cons(x) = x[1] > 0
extreme_constraint_index = AddExtremeConstraint(p, cons)
```

Progressive barrier constraints may be violated, transforming the optimization into a dual-objective form that attempts to decrease the amount that the constraint is violated by. Functions that implement a progressive barrier constraint should take a point input and return a numerical value that indicates the constraint violation amount. Added via `AddProgressiveConstraint`:

```julia
cons(x) = x[1]
progressive_constraint_index = AddProgressiveConstraint(p, cons)
```

These functions return an index that will, in future, be used to refer to the corresponding constraints for modification. Both `AddExtremeConstraint` and `AddProgressiveConstraint` can also be supplied a vector of functions, to save adding constraints individually. In this case, they will return a vector of indexes.

Constraints are stored in data structures named 'Collections'. Each collection can contain any number of constraints of the same type. By default, extreme barrier constraints are stored in collection one, and progressive barrier constraints in collection two. 

New collections can be created with the following functions:
```julia
new_progressive_collection_index = AddProgressiveCollection(p);
new_extreme_collection_index = AddExtremeCollection(p);
```
The collection contains configuration options for the constraints within it. For example, by default the progressive barrier collection uses a square norm when summing constraint violation, this can be configured to something like an L1 norm by defining a new collection.

## Method Choice

MADS defines two stages in each iteration: search and poll. The search stage employs an arbitrary strategy to look for an improved point in the current mesh. This can be designed to take advantage of a known property of the objective function's structure, or be something generic, for example, a random search. The poll step is a more rigorously defined exploration in the local space around the incumbent point. This allows for convergence analysis.

The choice of poll and search strategies are set in `DSProblem`:
```julia
p = DSProblem(3; poll=LTMADS(), search=NullSearch())
```
The combination of `LTMADS()` and `NullSearch()` is the default choice. This runs an LTMADS poll stage, and no search stage. The package also includes a simple random point search step, accessed with `RandomSearch(N)`, where N is the number of random points to generate. It would be great if any custom searches could be contributed back to the package.

## Custom Algorithms
Implementing a custom search or poll step is relatively simple. This requires the implementation of a custom type that configures the step, and a corresponding function that implements the stage. For example, a very simple random search around the current incumbent point could be defined with the struct:
```julia
struct RandomLocalSearch <: AbstractSearch
    # Number of points to generate
    N::Int 
    # Maximum distance to explore
    d::Float64
end
```
And then the corresponding implementation with a method of the function `GenerateSearchPoints`:
```julia
function GenerateSearchPoints(p::DSProblem{T}, s::RandomLocalSearch)::Vector{Vector{T}} where T
    points = []
    # Generating s.N points
    for i in 1:s.N
        # Generate offset vector
        offset = zeros(p.N)
        offset[rand(1:p.N)] = rand(-s.d:s.d)
        # Append to points list
        push!(points, p.x + offset)
    end
    # Return list
    return points
end
```
Any implementation of `GenerateSearchPoints` should take and return the shown arguments. This can then be used as with any other Search method:

```julia
p = DSProblem(3; poll=LTMADS(), search=RandomLocalSearch(5, 0.1));
```
Note that this search method it is unlikely to give good results due to not adapting the direction variable `d` to the current mesh size. 

A poll step can be implemented in a very similar manner. However, for most cases a poll stage should return a direction, not a discrete point. Therefore the function `GenerateDirections` should be overridden instead. As with the search step, this takes the problem as the first argument and the poll type as the second, and returns a vector of directions. A struct configuring a poll type must inherit the `AbstractPoll` type. As an example, please see the file `src/LTMADS.jl`.

## Future Features
- Orthomads implementation
- More flexible stopping conditions
- Better result/parameter access methods
- Larger variety of search stages
