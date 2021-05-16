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
        append!(points, [SafePointGeneration(p.x, d, p.config.mesh) for d in eachcol(dirs)])
    end
    if !isnothing(p.i)
        append!(points, [SafePointGeneration(p.i, d, p.config.mesh) for d in eachcol(dirs)])
    end

    p.full_output && OutputPollStep(points, dirs)

    return points
end

function SafePointGeneration(x::Vector{T}, d::SubArray, m::Mesh{T})::Vector{T} where T
    result = []

    for i=1:length(x)
        single_result = x[i] + (d[i] * m.δ[i])
        push!(result, m.digits[i] !== nothing ? round(single_result, digits=m.digits[i]) : single_result)
    end
    return result
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
