export ReportConfig, ReportStatus, ReportProblem
#TODO add ability to save report every X iterations
#TODO read report file to warm-start solver

const tab1 = "\t"
const tab2 = "\t\t"
const tab3 = "\t\t\t"

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
    push!(entries, "Opportunistic" => p.config.opportunistic)
    push!(entries, "Number of threads" => p.config.num_threads)
    push!(entries, "Max simultanious evaluations" => p.config.max_simultaneous_evaluations)
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
    push!(entries, "Cache hits" => p.status.cache_hits)
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

ReportFinal(p::DSProblem) = print(report_final(p))

function report_final(p::DSProblem)::ReportSection
    entries = []
    push!(entries, "Feasible Solution" => p.x)
    push!(entries, "Feasible Cost" => p.x_cost)
    push!(entries, "Infeasible Solution" => p.i)
    push!(entries, "Infeasible Cost" => p.i_cost)

    push!(entries, nothing)

    push!(entries, "Iterations" => p.status.iteration)
    push!(entries, "Function Evaluations" => p.status.function_evaluations)
    push!(entries, "Cache hits" => p.status.cache_hits)
    push!(entries, "Optimization Status" => p.status.optimization_status_string)

    push!(entries, nothing)

    push!(entries, "Runtime" => p.status.runtime_total)
    push!(entries, "Search Time" => p.status.search_time_total)
    push!(entries, "Poll Time" => p.status.poll_time_total)
    push!(entries, "Blackbox Evaluation Time" => p.status.blackbox_time_total)

    return ReportSection("MADS Run Summary", entries)
end

function OutputIterationDetails(p::DSProblem)
    str = ""

    title = "Iteration #$(p.status.iteration):"
    border = join(["=" for _ in 1:length(title)])

    str *= border * "\n"
    str *= title * "\n"
    str *= border * "\n"

    str *= "\n"

    str *= "Status:" * "\n"

    str *= tab1 * "Number of blackbox evaluations: $(p.status.function_evaluations)" * "\n"
    str *= tab1 * "Number of cache hits: $(p.status.cache_hits)" * "\n"

    str *= "\n"

    str *= PointDetails(p)

    str *= MeshDetails(p)

    print(str)
end

MeshDetails(p::DSProblem) = MeshDetails(p.config.mesh)
function MeshDetails(m::IsotropicMesh)::String
    str = ""
    str *= tab1 * "Mesh:" * "\n"
    str *= tab2 * "Mesh size: $(m.δ)" * "\n"
    str *= tab2 * "Poll size: $(m.Δ)" * "\n"
    str *= tab2 * "Mesh index: $(m.l)" * "\n"
    str *= "\n"
    return str
end

function PointDetails(p::DSProblem)::String
    str = ""

    str *= tab1 * "Feasible point: " * "\n"
    str *= tab2 * "x = $(p.x)" * "\n"
    str *= tab2 * "f(x) = $(p.x_cost)" * "\n"

    str *= "\n"

    str *= tab1 * "Infeasible point: " * "\n"
    str *= tab2 * "i = $(p.i)" * "\n"
    str *= tab2 * "f(i) = $(p.i_cost)" * "\n"

    str *= "\n"

    return str
end

function InitialPointEvaluationOutput(p::DSProblem, feasibility::ConstraintOutcome)
    str = ""

    title = "Evaluating initial point:"
    border = join(["=" for _ in 1:length(title)])

    str *= border * "\n"
    str *= title * "\n"
    str *= border * "\n"

    str *= "\n"

    if feasibility == Feasible
        str *= tab1 * "x₀ = $(p.x)" * "\n"
        str *= tab1 * "f(x₀) = $(p.x_cost)" * "\n"
        str *= tab1 * "Feasibility: Feasible" * "\n"
    else
        str *= tab1 * "x₀ = $(p.i)" * "\n"
        str *= tab1 * "f(x₀) = $(p.i_cost)" * "\n"
        str *= tab1 * "Feasibility: Weak Infeasible" * "\n"
    end
    
    str *= "\n"

    print(str)
end

function OutputSearchStep(p::DSProblem{T}, points::Vector{Vector{T}}) where T
    str = ""

    if p.config.search isa NullSearch
        str *= tab1 * "Skipping Search step." * "\n"
    else
        str *= tab1 * "Generated search points:" * "\n"
        for i=1:length(points)
            str *= tab2 * "Search point $i: $(points[i])" * "\n"
        end
    end

    str *= "\n"

    print(str)
end

function OutputPollStep(points::Vector{Vector{T}}, directions::Matrix{T}) where T
    str = ""

    str *= tab1 * "Generated directions:" * "\n"
    for i=1:size(directions,2)
        str *= tab2 * "Direction $i: $(directions[:,i])" * "\n"
    end

    str *= "\n"

    str *= tab1 * "Generated poll points:\n" * "\n"
    for i=1:length(points)
        str *= tab2 * "Poll point $i: $(points[i])" * "\n"
    end

    str *= "\n"

    print(str)
end

function OutputPointEvaluation(i::Int, point::Vector{T}, cost::T, h::T, is_from_cache::Bool, threadId::Union{Int, Nothing}=nothing) where T
    str = ""

    if threadId !== nothing
        str *= tab2 * "Evaluating point $i with Thread $threadId:" * "\n"
    else
        str *= tab2 * "Evaluating point $i:" * "\n"
    end
    
    str *= tab3 * "x = $point" * "\n"
    str *= tab3 * "f(x) = $cost" * "\n"
    str *= tab3 * "h(x) = $h" * "\n"
    if is_from_cache
        str *= tab3 * "Point was found in cache." * "\n"
    end
    str *= "\n"

    print(str)
end
