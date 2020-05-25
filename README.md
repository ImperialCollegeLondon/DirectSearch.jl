# DirectSearch.jl
<!-- Currently isn't a stable release -->
<!--[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/stable)-->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/dev)
[![Build Status](https://travis-ci.com/EdwardStables/DirectSearch.jl.svg?branch=master)](https://travis-ci.com/EdwardStables/DirectSearch.jl)

*This is a temporary mirror of the [main project repo](https://github.com/ImperialCollegeLondon/DirectSearch.jl)*

DirectSearch.jl provides a framework for the implementation of direct search algorithms, currently focusing on the Mesh Adaptive Direct Search (MADS) family. These are derivative free, black box algorithms, meaning that no analytical knowledge of the objective function or any constraints are needed. This package provides the core MADS algorithms (LTMADS, OrthoMADS, as well as progressive and extreme barrier constraints), and is designed to allow custom algorithms to be easily added.

## Installation

This package is not yet registered. Install with:
```julia
pkg> add https://github.com/EdwardStables/DirectSearch.jl
```
And import as with any Julia package:
```julia
using DirectSearch
```

## Usage

A more detailed guide is available in the [documentation](https://EdwardStables.github.io/DirectSearch.jl/dev/man/usage).

A problem is defined with `DSProblem(N)`, where N is the dimension of the problem. The objective function and initial point need to be set before optimization can run.
```julia
obj(x) = x'*[2 1;1 4]*x + x'*[1;4] + 7;
p = DSProblem(2; objective=obj, initial_point=[1.0,2.0]);
```
Note that the objective function is assumed to take a vector of points of points as the input, and return a scalar cost. The initial point should be an array of the same dimensions of the problem, and feasible with respect to any extreme barrier constraints. See `DSProblem`'s documentation for a full list of parameters.

Parameters can also be set after generation of the problem:
```julia
p = DSProblem(2)
SetInitialPoint(p, [1.0,2.0])
SetObjective(p,obj)
```

Run the algorithm with `Optimize!`.
```julia
Optimize!(p)
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
*(Functions for accessing this data will be added in future.)*

Two kinds of constraints are included, progressive barrier, and extreme barrier constraints. As with the objective function, these should be specified as a Julia function that takes a vector, and returns a value. 

### Extreme Barrier Constraints
Extreme barrier constraints are constraints that cannot be violated, and their function should return boolean (true for a feasible point, false for infeasible), or a numerical value giving the constraint violation amount (≤0 for feasible, >0 for infeasible). Added with `AddExtremeConstraint`:

```julia
cons(x) = x[1] > 0 #Constrains x[1] to be larger than 0
AddExtremeConstraint(p, cons)
```

### Progressive Barrier Constraints
Progressive barrier constraints may be violated, transforming the optimization into a dual-objective form that attempts to decrease the amount that the constraint is violated by. Functions that implement a progressive barrier constraint should take a point input and return a numerical value that indicates the constraint violation amount (≤0 for feasible, >0 for infeasible). Added via `AddProgressiveConstraint`:

```julia
cons(x) = x[1] #Constraints x[1] to be less than or equal to 0
AddProgressiveConstraint(p, cons)
```
