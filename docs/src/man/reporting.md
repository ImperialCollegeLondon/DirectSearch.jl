# Reporting

## Detailed Outputting

To get a more detailed output during the optimization process, the `full_output` parameter may be set during the instantiation of `DSProblem`:

```julia
p = DSProblem(3; full_output=true)
```

This will result in a detailed output of each iteration to the terminal, consisting of information on the optimization parameters, incumbent feasible and infeasible points, search step, poll step, and trial point evaluations. 

## Reports

In order to generate reports about the finished optimization process the functions `ReportConfig`, `ReportStatus`, and `ReportProblem` can be called providing the `DSProblem` instance as the argument. `ReportConfig` details the configuration options, `ReportStatus` details the non-problem-specific information, while `ReportProblem` details the problem specific information.
