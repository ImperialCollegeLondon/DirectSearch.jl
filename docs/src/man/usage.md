# Usage

DirectSearch.jl provides a framework for the implementation of direct search algorithms, currently focusing on the Mesh Adaptive Direct Search (MADS) family. These are derivative free, black box algorithms, meaning that no analytical knowledge of the objective function or any constraints are needed. This package provides the core MADS algorithms (LTMADS, OrthoMADS, granular variables and dynamic scaling, as well as progressive and extreme barrier constraints), and is designed to allow custom algorithms to be easily added.

## Install
To install the package, use the following command
```
pkg> add https://github.com/lb4418/DirectSearch.jl#lb
```

And import as with any Julia package:
```julia
using DirectSearch
```

## Problem Specification
The core data structure is the `DSProblem` type. At a minimum it requires the dimension of the problem:
```julia
p = DSProblem(3);
```
The objective function, initial point, and other parameters may be specified in `DSProblem`:
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
SetIterationLimit(p, 500)
```

### Variable Bounds
The bounds of problem variables can be set with `SetVariableBound` or `SetVariableBounds`. These values are used to set the initial poll sizes of each variable. By default the variables are defined as unbounded.

If a bound for a single variable is required to be defined, it can be set with `SetVariableBound`. `i` is the index of the variable, and the following numbers are the upper and lower bound of the variable respectively.
```julia
SetVariableBound(p, i, 10000, 20000)
```

The same operation can be applied to all variables with `SetVariableBounds` (example for N=3):
```julia
SetVariableBounds(p, [10000, -5, -10000], [20000, 5, 10000])
```

Be aware that this **does not** add a constraint on the variable, it **only** gives additional information when defining the initial poll size, which acts as the initial scaling of the variables. Constraints on variable range should be added explicitly as constraints.

### Granular Variables
If variables other than continuous, such as integers, are desired to be used, this can be specified through the granularity of the problem variables. The granularity is taken to be 0 for continuous variables and 1 for integers. The granularity can be any non-negative value.

If the granularity for a single variable is required to be defined, it can be set with `SetGranularity`. `i` is the index of the variable, and the following number is the granularity.
```julia
SetGranularity(p, i, 0.1)
```

The same operation can be applied to all variables with `SetGranularities` (example for N=3):
```julia
SetGranularities(p, [1.0, 0.1, 0.01])
```

### Optimizing
Run the algorithm with `Optimize!`.
```julia
Optimize!(p)
```
This will run MADS until one of the defined stopping conditions is met. By default, the stopping conditions are set to the iteration limit (default 1000), function evaluation limit (default 5000), mesh precision limit (`Float64` precision) and poll precision limit (`Float64` precision). For more details on stopping conditions, and how to add a custom one see [Adding Stopping Conditions](@ref).

After optimization is finished, the detailed results are printed as in the following example:

```
==================================================
MADS Run Summary
--------------------------------------------------
Feasible Solution           [1.0005, 10.0]
Feasible Cost               0.0
Infeasible Solution         nothing
Infeasible Cost             nothing

Iterations                  52
Function Evaluations        196
Cache hits                  13
Optimization Status         Mesh Precision limit

Runtime                     0.9472651481628418
Search Time                 4.499999999999997e-6
Poll Time                   0.4502825000000001
Blackbox Evaluation Time    0.00048089999999999917
```

### Type Parameterisation
By default, `DSProblem` is parameterised as `Float64`, but this can be overridden:
```julia
p = DSProblem{Float32}(3);
```
However, this is mostly untested and will almost certainly break. It is included to allow future customisation to be less painful.

### Parallel Blackbox Evaluations
If Julia was started with more than one thread using the option `--threads N` where `N` is the number of threads, then DirectSearch.jl can be configured to evaluate the objective functions in parallel using multiple threads. This can done by calling the function `SetMaxEvals`:
```julia
SetMaxEvals(p)
```

Note that using multiple threads is only beneficial when the function to evaluate takes a long time using a single thread (1ms or more). Otherwise, the runtime will increase due to multi-threading overheads.

## Constraints
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

### Equality Constraints
The package does not care about the form of constraints (as they are treated like a black box). However in many cases, the algorithm will not be able to generate trial points that are exactly able to satisfy equality constraints. 

Therefore, to implement extreme barrier equality constraints a tolerance should be included in the constraint function. Alternatively progressive barrier constraints can be used, but it is likely that the algorithm will not be able to generate feasible solutions, but the final point should be very close to feasible.

### Constraint Indexes
The functions to add a constraint return an index that can be used to refer to the constraints for modification. When supplied with a vector of functions both constraint functions will return a vector of indexes.

Currently these indexes have no direct use. But functions to ignore constraints will be added in future.

### Collections
Constraints are stored in data structures named 'Collections'. Each collection can contain any number of constraints of the same type. By default, extreme barrier constraints are stored in collection one, and progressive barrier constraints in collection two. In most cases, collections can be ignored.

New collections can be created with the following functions:
```julia
AddProgressiveCollection(p);
AddExtremeCollection(p);
```
The collection contains configuration options for the constraints within it. For example, by default the progressive barrier collection uses a square norm when summing constraint violation, this can be configured to use an alternate norm by defining a new collection. See the documentation for the individual functions for all the possible configuration options.

As with adding individual constraints, collections return an index. This is useful for specifying a collection to add a constraint to. These indexes will also be used to refer to the collections for modification in future. 

## Method Choice

MADS defines two stages in each iteration: search and poll. 

### Search

The search stage employs an arbitrary strategy to look for an improved point in the current mesh. This can be designed to take advantage of a known property of the objective function's structure, or be something generic, for example, a random search, or ignored. 

A search step returns a set of points that are then evaluated on the objective function.

The choice of search strategy is set in `DSProblem`:
```julia
p = DSProblem(3; search=RandomSearch(10))
```
The current included search strategies are `NullSearch` and `RandomSearch`. `NullSearch` will perform no search stage and is the default choice. `RandomSearch` will select M random points on the current mesh, where M is the option given to it when instantiated.

### Poll
The poll step is a more rigorously defined exploration in the local space around the incumbent point.

Poll steps return a set of directions that are then evaluated with a preset distance value.

As with the search step, it is set in `DSProblem`:
```julia
p = DSProblem(3; poll=LTMADS())
p = DSProblem(3; poll=OrthoMADS())
```
Two poll steps are included. The first is LTMADS, which generates a set of directions from a basis generated from a semi-random lower triangular matrix. The other is OrthoMADS, a later algorithm that generates an orthogonal set of directions. It was recently adapted to granular variables as in 2019 C. Audet, S. Le Digabel, and C. Tribes, but the same name is continued to be used. By default, LTMADS is used.

Both OrthoMADS and LTMADS are non-deterministic, and will therefore give different results every time they are run. For this reason, they may need several runs to achieve their best results.
## Custom Algorithms
DirectSearch.jl is designed to make it simple to add custom search and poll stages. See [Adding a Search Step](@ref) and [Adding a Poll Step](@ref) for an overview of this.

