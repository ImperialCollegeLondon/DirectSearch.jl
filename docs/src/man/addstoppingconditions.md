# Adding Stopping Conditions

The software runs the optimization process until one of the stopping conditions. There are five stopping conditions, which may be used by the users, or they can define their own.

## Implementation

Each stopping condition is defined as a concrete type of the abstract type `AbstractStoppingCondition`. Two functions are required to be defined to successfully use the stopping condition - `CheckStoppingCondition` and `StoppingConditionStatus`.

`CheckStoppingCondition` is used to check if the optimization proccess should continue. `s` is the instance of the concrete stopping condtion type. If the optimization process needs to stop, the function should return `false`, otherwise return `true`.

```julia
(CheckStoppingCondition(p::DSProblem, s::T) where T <: AbstractStoppingCondition)::Bool
```

`StoppingConditionStatus` defines the textual representation of the stopping condition, which is used in reporting. It takes as argument the instance of the concrete stopping condition type and should return a `string`. If this function is ommited, then the stopping condition status will be represented as "Unknown stopping condition status".

```julia
(StoppingConditionStatus(::T) where T <: AbstractStoppingCondition)::String
```

When the stopping condition type and functions are defined, they can be added to the problem using the function `AddStoppingCondition`, which takes as the first argument the `DSProblem` instance, and as the second argument the stopping condition instance.

```julia
function AddStoppingCondition(p::DSProblem, c::T) where T <: AbstractStoppingCondition
    push!(p.stoppingconditions, c)
end
```

## Native

There are currently five stopping conditions that may be used:

- Iteration Limit (`IterationStoppingCondition`)
- Function Evaluation Limit (`FunctionEvaluationStoppingCondition`)
- Mesh Precision (`MeshPrecisionStoppingCondition`)
- Poll Precision (`PollPrecisionStoppingCondition`)
- Runtime Limit (`RuntimeStoppingCondition`)

The first four stopping conditions are automatically included in each problem instance, and the runtime limit can be added using `AddStoppingCondition`.
