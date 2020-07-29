#export report, ReportConstraints

#TODO add ability to save report every X iterations
#TODO read report file to warm-start solver
#TODO report file can be configured with cache, inner vars, points etc.

struct ReportSection
    title::String
    entries::Vector{Union{Pair{String,Any},Nothing}}
end

Base.println(p::DSProblem) = print(p)
function Base.print(p::DSProblem)
    print(report_config(p))
    println()
    print(report_status(p))
    println()
    print(report_problem(p))
end

Base.println(s::ReportSection) = print(s)
function Base.print(s::ReportSection)
    spacenumber = max(length.([e.first for e in s.entries if e != nothing])...) + 4
    maxwidth = max(length.([string(e.second) for e in s.entries if e != nothing])...) + spacenumber

    println(join(["=" for _ in 1:maxwidth]))
    println(s.title)
    println(join(["-" for _ in 1:maxwidth]))

    for e in s.entries
        if e == nothing
            println()
        else
            print(e.first)
            print(join([" " for _ in 1:spacenumber - length(e.first)]))
            println(e.second)
        end
    end
end

"""
    report_config(p::DSProblem)::ReportSection

Format the contents of `p.config` to a DS.ReportSection. This information details
the configuration options that are not directly related to the solver.
"""
function report_config(p::DSProblem)::ReportSection
    entries = []
    push!(entries, "Search" => typeof(p.config.search))
    push!(entries, "Poll" => typeof(p.config.poll))
    push!(entries, "Mesh" => typeof(p.config.mesh))
    push!(entries, "Mesh Scale" => p.config.meshscale)
    push!(entries, "Opportunistic" => p.config.opportunistic)
    push!(entries, "Number of processes" => p.config.num_procs)
    push!(entries, "Max simultanious evaluations" => p.config.max_simultanious_evaluations)
    return ReportSection("Config", entries)
end

function report_status(p::DSProblem)::ReportSection
    entries = []
    push!(entries, "Function Evaluations" => p.status.function_evaluations)
    push!(entries, "Iterations" => p.status.iteration)
    push!(entries, "Optimization Status" => p.status.optimization_status)

    push!(entries, nothing)

    push!(entries, "Runtime" => p.status.runtime_total)
    push!(entries, "Search Time" => p.status.search_time_total)
    push!(entries, "Poll Time" => p.status.poll_time_total)
    push!(entries, "Blackbox Evaluation Time" => p.status.blackbox_time_total)
    return ReportSection("Status", entries)
end

function report_problem(p::DSProblem)::ReportSection
    entries = []
    push!(entries, "Variables" => p.N)
    push!(entries, "Initial Point" => p.user_initial_point)
    push!(entries, "Sense" => p.sense)

    push!(entries, nothing)

    push!(entries, "Feasible Solution" => p.x)
    push!(entries, "Feasible Cost" => p.x_cost)
    push!(entries, "Infeasible Solution" => p.i)
    push!(entries, "Infeasible Cost" => p.i_cost)
    return ReportSection("Optimization Problem", entries)
end

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

