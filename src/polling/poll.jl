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
            push!(points, PollPointGeneration(p.x, d, p.config.mesh))
            push!(directions, d)
        end
    end
    if !isnothing(p.i)
        for i=1:size(dirs,2)
            d = dirs[:,i]
            push!(points, PollPointGeneration(p.i, d, p.config.mesh))
            push!(directions, d)
        end
    end

    p.status.directions = directions

    p.full_output && OutputPollStep(points, dirs)

    return points
end


"""
    GenerateDirections(p::DSProblem)

Generate a set of directions with the configured polling algorithm.
"""
function GenerateDirections(p::DSProblem)
    directions = GenerateDirections(p, p.config.poll)
    return mapslices(dir -> ScaleDirection(p.config.mesh, dir), directions, dims = 1)
end

Name(::AbstractPoll) = "Unknown poll type"
