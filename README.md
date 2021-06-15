# DirectSearch.jl
<!-- Currently isn't a stable release -->
<!--[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://imperialcollegelondon.github.io/DirectSearch.jl/stable)-->
<!-- [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://imperialcollegelondon.github.io/DirectSearch.jl/dev)
![](https://github.com/ImperialCollegeLondon/DirectSearch.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/ImperialCollegeLondon/DirectSearch.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/ImperialCollegeLondon/DirectSearch.jl) -->


DirectSearch.jl provides a framework for the implementation of direct search algorithms, currently focusing on the Mesh Adaptive Direct Search (MADS) family. These are derivative free, black box algorithms, meaning that no analytical knowledge of the objective function or any constraints are needed. This package provides the core MADS algorithms (LTMADS, OrthoMADS, granular variables and dynamic scaling, as well as progressive and extreme barrier constraints), and is designed to allow custom algorithms to be easily added.

## Installation

This package is not yet registered. Install with:
```
pkg> add https://github.com/lb4418/DirectSearch.jl#lb
```
And import as with any Julia package:
```julia
using DirectSearch
```

## Usage

A more detailed guide is available in the [documentation](https://lb4418.github.io/DirectSearch.jl/lb/man/usage/).

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
This will run MADS until one of the defined stopping conditions is met. By default, the stopping conditions are set to the iteration limit (default 1000), function evaluation limit (default 5000), mesh precision limit (`Float64` precision) and poll precision limit (`Float64` precision). For more details on stopping conditions, and how to add a custom one see [Adding Stopping Conditions](https://lb4418.github.io/DirectSearch.jl/lb/man/addstoppingconditions/) in the documentation.

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

### Constraints
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
