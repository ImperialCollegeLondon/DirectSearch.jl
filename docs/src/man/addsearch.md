# Adding a Search Step

## Implementation
Implementing a custom search strategy is relatively simple. It requires the implementation of a type that configures the step, and a corresponding function that implements it. The configuration type should inherit from `AbstractSearch`, and the function should be an implementation of the `GenerateSearchPoints` function that takes a `DSProblem` and your custom type as arguments, and returns a vector of vectors.


For example, a very simple random search around the current incumbent point could be defined with the struct:
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
This can then be used as with any other search method:

```julia
p = DSProblem(3; poll=LTMADS(), search=RandomLocalSearch(5, 0.1));
```
*(Note that this search method it is unlikely to give good results due to not adapting the direction variable `d` to the current mesh size.)*

## Organisation
Unless it is very simple (ie, fits within a single function) please implement your search method in its own file. This ensures that extra functions that are part of the method are kept in a relevant place. 

If a custom search method may be useful to other people, please consider contributing it back to the package.
