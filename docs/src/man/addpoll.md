# Adding a Poll Step

## Implementation 
A poll step can be implemented in a very similar manner to a search step. However, a poll stage should return a direction, not a discrete point. Therefore the function `GenerateDirections` should be overridden instead. As with the search step, this takes the problem as the first argument and the poll type as the second, and returns a vector of directions. A struct configuring a poll type must inherit the `AbstractPoll` type. As an example, please see the file `src/LTMADS.jl`.

Note that, for the convergence properties of MADS to hold, the poll step has several requirements, and therefore it is generally recommended to use LTMADS or OrthoMADS and modify the search stage to fit the problem.

## Organisation
Custom poll stages should be included in their own file.
