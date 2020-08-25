export ReportConfig, ReportStatus, ReportProblem
#TODO add ability to save report every X iterations
#TODO read report file to warm-start solver

struct ReportSection
    title::String
    entries::Vector{Union{Pair{String,Any},Nothing}}
end

"""
    ReportConfig(p::DSProblem)

Print the configuration options currently used by `p`.
"""
ReportConfig(p::DSProblem) = print(report_config(p))

"""
    ReportStatus(p::DSProblem)

Print the current non-problem-specific status information of `p`.
"""
ReportStatus(p::DSProblem) = print(report_status(p))

"""
    ReportProblem(p::DSProblem)

Print the current problem specific status information of `p`.
"""
ReportProblem(p::DSProblem) = print(report_problem(p))

"""
    Base.print(p::DSProblem)

Print the output of [`ReportConfig`](@ref), [`ReportStatus`](@ref), and [`ReportProblem`](@ref) in a list.
"""
Base.print(p::DSProblem) = format_problem(p)
Base.println(p::DSProblem) = print(p)
function format_problem(p::DSProblem)
    print(report_config(p))
    println()
    print(report_status(p))
    println()
    print(report_problem(p))
end

Base.println(s::ReportSection) = print(s)
Base.print(s::ReportSection) = print(format(s))
function format(s::ReportSection)
    str = ""
    spacenumber = max(length.([e.first for e in s.entries if e != nothing])...) + 4
    maxwidth = max(length.([string(e.second) for e in s.entries if e != nothing])...) + spacenumber

    str *= join(["=" for _ in 1:maxwidth]) * "\n"
    str *= s.title * "\n"
    str *= join(["-" for _ in 1:maxwidth]) * "\n"

    for e in s.entries
        if e == nothing
            str *= "\n"
        else
            str *= e.first
            str *= join([" " for _ in 1:spacenumber - length(e.first)])
            str *= string(e.second)
            str *= "\n"
        end
    end

    return str
end

"""
    report_config(p::DSProblem)::ReportSection

Format the contents of `p.config` to a DS.ReportSection. This information details
the configuration used by `p`.
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

"""
    report_status(p::DSProblem)::ReportSection

Format the contents of `p.status` to a DS.ReportSection. This information details
the current state of the solver in regards to non-problem specific information.
"""
function report_status(p::DSProblem)::ReportSection
    entries = []
    push!(entries, "Function Evaluations" => p.status.function_evaluations)
    push!(entries, "Iterations" => p.status.iteration)
    push!(entries, "Optimization Status" => p.status.optimization_status)
    push!(entries, "Optimization Status String" => p.status.optimization_status_string)

    push!(entries, nothing)

    push!(entries, "Runtime" => p.status.runtime_total)
    push!(entries, "Search Time" => p.status.search_time_total)
    push!(entries, "Poll Time" => p.status.poll_time_total)
    push!(entries, "Blackbox Evaluation Time" => p.status.blackbox_time_total)
    return ReportSection("Status", entries)
end

"""
    report_problem(p::DSProblem)::ReportSection

Format the contents of `p` to a DS.ReportSection. This information details
the current problem-specific state of the solver.
"""
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

