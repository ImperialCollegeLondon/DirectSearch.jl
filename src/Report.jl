#export report, ReportConstraints

#TODO add ability to save report every X iterations
#TODO read report file to warm-start solver
#TODO report file can be configured with cache, inner vars, points etc.

"""
    report_finish(p::DSProblem)

**Not Implemented**

If not silent, give a short printout of the result of the problem.

States the duration, final point, final cost, and reason for stopping.
A more detailed report can be shown with `report`.
"""
function report_finish(p::DSProblem)

end

"""
    report(p::DSProblem; save::Union{Bool,String}=false)

Prints a summary of the problem to the console, or saves it as a text file.

`save=true` saves the report in the current REPL directory, but will error 
if the default file name `report` is taken. Otherwise give a path as an argument
to use that name.

The report contains the solver configuration, the initial and final incumbent points,
the initial and final cost, the duration, the number of iterations, and the current
status.
"""
function report(p::DSProblem; save::Union{Bool,String}=false,
               print_problem=true, print_solver=true, print_config=true)
    problem =
"""
---------------------------------
Problem Status
---------------------------------
Incumbent Point:    $(p.x)
Current Cost:       $(p.x_cost)

Initial Point:      $(p.x_initial)
Initial Cost:       $(p.x_initial_cost)

Variables:          $(p.N)
Variable Scaling:   $(p.meshscale)

"""
    solver =
"""
---------------------------------
Solver Status
---------------------------------
Status:             $(p.status) 
Iterations:         $(p.iteration)

Duration:           To be added

"""

    config = 
"""
---------------------------------
Solver Configuration
---------------------------------
Sense:              $(p.sense) 

Mesh:               $(typeof(p.mesh))
Search Directions:  To be added
Poll Directions:    $(typeof(p.poll))

"""
    report_str = "Direct Search Optimisation Report\n=================================\n" 

    if print_problem
        report_str *= problem 
    end
    if print_solver
        report_str *= solver
    end
    if print_config
        report_str *= config
    end

    report_str *= "================================="

    println(report_str)
end

"""
    export_points(p::DSProblem)

Gives the trace of considered points during optimisation. Note that this is unavailable
if tracking of points has been disabled 
"""
function export_points(p::DSProblem)
    for x in p.cache.order
        println("$(x)\t$(p.cache.costs[x])")
    end
end

ReportConstraints(p::DSProblem) = ReportConstraints(p.constraints)
function ReportConstraints(c::Constraints{T}) where T
    constraint_report=
"""
---------------------------------
Constraints
---------------------------------
Constraint Collections:     $(c.count)
Populated Collections:      $(length([col for col in c.collections if col.count > 0]))
Total Constraints:          $(sum([col.count for col in c.collections]))
"""
    print(constraint_report)
    for (index, collection) in enumerate(c.collections)
        println("\n$(CollectionIndex(index)) : $(typeof(collection))")
        ReportConstraintCollection(collection)
    end
end


function ReportConstraintCollection(c::ConstraintCollection{T, C}) where {T,C}
    collection_report = 
"""
Constraints:       $(c.count)
Ignored:           $(c.ignore)
h_max:             $(c.h_max)
h_max update 
function handle:   $(c.h_max_update)
result aggregate 
function handle:   $(c.result_aggregate)
"""
    print(collection_report)
end

