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
```@docs
ReportConfig
ReportStatus
ReportProblem
Base.print
```
