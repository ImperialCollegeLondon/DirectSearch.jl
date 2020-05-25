# Public API

These functions and types implement the API of DirectSearch.jl. 

## Problem Configuration
```@docs
DSProblem
SetObjective
SetInitialPoint
Optimize!
SetIterationLimit
SetVariableRange
SetVariableRanges
BumpIterationLimit
ProblemSense
SetMaxEvals
```
## Search Stages
```@docs
NullSearch
RandomSearch
```

## Poll Stages
```@docs
LTMADS
OrthoMADS
```

## Constraints 
```@docs
AddExtremeConstraint(p::DirectSearch.AbstractProblem, f::Function)
AddExtremeConstraint(p::DirectSearch.AbstractProblem, f::Vector{Function})
AddProgressiveConstraint(p::DirectSearch.AbstractProblem, f::Function)
AddProgressiveConstraint(p::DirectSearch.AbstractProblem, f::Vector{Function})
AddExtremeCollection(p::DirectSearch.AbstractProblem)
AddProgressiveCollection(p::DirectSearch.AbstractProblem)
DefaultExtremeRef
DefaultProgressiveRef
```

## Reporting
**Many functions in this section are out of date, do not rely on them to give accurate information**
```@docs
DirectSearch.report_finish
DirectSearch.report
DirectSearch.export_points
DirectSearch.ReportConstraints(::DSProblem)
DirectSearch.ReportConstraintCollection
```
