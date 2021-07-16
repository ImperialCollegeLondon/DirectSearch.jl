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

    directions = []

    if !isnothing(p.x)
        for i=1:size(dirs,2)
            d = dirs[:,i]
            push!(points, SafePointGeneration(p.x, d, p.config.mesh))
            push!(directions, d)
        end
    end
    if !isnothing(p.i)
        for i=1:size(dirs,2)
            d = dirs[:,i]
            push!(points, SafePointGeneration(p.i, d, p.config.mesh))
            push!(directions, d)
        end
    end

    p.status.directions = directions

    p.full_output && OutputPollStep(points, dirs)

    return points
end

"""
    SafePointGeneration(x::Vector{T}, d::Vector{T}, m::Mesh{T})::Vector{T} where T

Generate a trial point around incumbent point `x`, using direction `d`, and removing
the potential low-level computational error for granular variables.
"""
(SafePointGeneration(x::Vector{T}, d::Vector{T}, m::Mesh{T})::Vector{T}) where T = SafePointGeneration(x, d, m.δ, m.digits)
function SafePointGeneration(x::Vector{T}, d::Vector{T}, δ::Vector{T}, digits::Vector{Union{Int, Nothing}})::Vector{T} where T
    result = []

    for i=1:length(x)
        single_result = x[i] + (d[i] * δ[i])
        push!(result, isnothing(digits[i]) ? single_result : round(single_result, digits=digits[i]))
    end
    return result
end

"""
    ScaleDirection(p::DSProblem, dir::Vector{T}) where T

Scale the direction using the mesh ratio vector ρ
"""
function ScaleDirection(p::DSProblem, dir::Vector{T}) where T
    infNorm = maximum(abs.(dir))

    if infNorm == 0
        error("Unexpected error. Poll algorithm generated a direction equal to zero.")
    end

    d_scaled = dir ./ infNorm

    return round.(d_scaled .* p.config.mesh.ρ)
end

"""
    GenerateDirections(p::DSProblem)

Generate a set of directions with the configured polling algorithm.
"""
function GenerateDirections(p::DSProblem)
    directions = GenerateDirections(p, p.config.poll)
    return mapslices(dir -> ScaleDirection(p, dir), directions, dims = 1)
end

Name(::AbstractPoll) = "Unknown poll type"
