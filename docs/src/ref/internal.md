# Internal API

These functions and types are for internal usage and should generally not be accessed during normal use of the package. This will likely be useful if implementing an extension to the package. 

Fully documenting every function is currently ongoing. Please raise an issue if information is missing.

## Core
```@docs
DirectSearch.EvaluateInitialPoint
DirectSearch.EvaluatePoint!
DirectSearch.EvaluatePointSequential!
DirectSearch.EvaluatePointParallel!
DirectSearch.function_evaluation
DirectSearch.function_evaluation_parallel
```

## Constraints
```@docs 
DirectSearch.AbstractConstraint
DirectSearch.IterationOutcome
DirectSearch.ConstraintOutcome
DirectSearch.CollectionIndex
DirectSearch.ConstraintIndex
DirectSearch.ConstraintCollection
DirectSearch.h_max_update
DirectSearch.AbstractProgressiveConstraint
DirectSearch.ProgressiveConstraint
DirectSearch.ExtremeConstraint
DirectSearch.Constraints
DirectSearch.CollectionTypeCount
DirectSearch.ConstraintUpdate!
DirectSearch.ConstraintEvaluation
DirectSearch.GetHmaxSum
DirectSearch.ConstraintCollectionEvaluation(::DirectSearch.ConstraintCollection{T,DirectSearch.ProgressiveConstraint}, ::Vector{T}) where T
DirectSearch.ConstraintCollectionEvaluation(::DirectSearch.ConstraintCollection{T,DirectSearch.ExtremeConstraint}, ::Vector{T}) where T
```

## Mesh
```@docs
DirectSearch.AbstractMesh
DirectSearch.MeshSetup!
DirectSearch.MeshUpdate!
DirectSearch.SetMeshParameters!
DirectSearch.SetMeshSizeVector!
DirectSearch.SetPollSizeVector!
DirectSearch.SetRatioVector!
DirectSearch.init_a_and_b!
DirectSearch.get_poll_size_estimate
```

## Poll
```@docs
DirectSearch.Poll
DirectSearch.GeneratePollPoints
DirectSearch.GenerateDirections(::DSProblem)
DirectSearch.SafePointGeneration
DirectSearch.ScaleDirection
```

## Search
```@docs
DirectSearch.Search
DirectSearch.GenerateSearchPoints(::DSProblem{T}) where T
DirectSearch.GenerateSearchPoints(::DSProblem{T}, ::RandomSearch) where T
DirectSearch.GenerateSearchPoints(::DSProblem, ::NullSearch)
```

## LTMADS
```@docs
DirectSearch.GenerateDirections(::DirectSearch.AbstractProblem, ::LTMADS{T}) where T
DirectSearch.form_basis_matrix
DirectSearch.LT_basis_generation
DirectSearch.B′_generation
DirectSearch.b_l_generation
DirectSearch.L_generation
DirectSearch.B_generation
```

## OrthoMADS
```@docs
DirectSearch.GenerateDirections(::DirectSearch.AbstractProblem, ::OrthoMADS)
DirectSearch.GenerateDirectionsOnUnitSphere
DirectSearch.HouseholderTransform
```

## Cache
```@docs
DirectSearch.AbstractCache
DirectSearch.PointCache
DirectSearch.CachePush(::DirectSearch.AbstractProblem{T}, ::Vector{T}, ::T) where T
DirectSearch.CachePush(::DirectSearch.AbstractProblem)
DirectSearch.CacheQuery(::DirectSearch.AbstractProblem, ::Vector)
DirectSearch.CacheGet(::DirectSearch.AbstractProblem, ::Vector)
DirectSearch.CacheRandomSample(::DirectSearch.AbstractProblem, ::Int)
DirectSearch.CacheInitialPoint(::DirectSearch.AbstractProblem)
DirectSearch.CacheGetRange(::DirectSearch.AbstractProblem, ::Vector)
DirectSearch.CacheFilter(::DirectSearch.AbstractProblem, ::Vector)
```
