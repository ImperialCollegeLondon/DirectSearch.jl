"""
    Poll(p::DSProblem{T})::IterationOutcome where T

Generate points and call evaluate on them.
"""
function Poll(p::DSProblem{T})::IterationOutcome where T
    p.status.poll_time_total += @elapsed points = GeneratePollPoints(p, p.config.mesh)
    return EvaluatePoint!(p, points)
end

"""
    GeneratePollPoints(p::DSProblem{T}, ::AbstractMesh)::Vector{Vector{T}} where T

Generate a set of directions with the configured polling algorithm, then return
the set of points these directions give from the incumbent points.
"""
function GeneratePollPoints(p::DSProblem{T}, ::AbstractMesh)::Vector{Vector{T}} where T
    points = Vector{T}[]
    dirs = GenerateDirections(p)

    if !isnothing(p.x)
        append!(points, [p.x+(p.config.mesh.δ .* d) for d in eachcol(dirs)])
    end
    if !isnothing(p.i)
        append!(points, [p.i+(p.config.mesh.δ .* d) for d in eachcol(dirs)])
    end

    p.full_output && OutputPollStep(points, dirs)

    return points
end

function ScaleDirection(p::DSProblem, dir::Vector{T}) where T
    infNorm = maximum(abs.(dir))

    if infNorm == 0
        error("Unexpected error. Poll algorithm generated a direction equal to zero.")
    end

    d_scaled = dir ./ infNorm

    return round.(d_scaled .* p.config.mesh.ρ)
end

function GenerateDirections(p::DSProblem)
    directions = GenerateDirections(p, p.config.poll)
    return mapslices(dir -> ScaleDirection(p, dir), directions, dims = 1)
end

Name(::AbstractPoll) = "Unknown poll type"
