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

    secondarycenter = nothing

    # Determine the primary polling center
    if isnothing(p.x)
        # Use the infeasible point as the center
        primarycenter = p.i
    elseif isnothing(p.i)
        # Use the feasible point as the center
        primarycenter = p.x
    else
        # Compare the current cost of each to determine the primary poll center
        if p.x_cost - p.frame_center_trigger > p.i_cost
            primarycenter   = p.i
            secondarycenter = p.x
        else
            primarycenter   = p.x
            secondarycenter = p.i
        end

    end

    # Generate the directions around the primary poll center
    for i=1:size(dirs,2)
        d = dirs[:,i]
        push!(points, PollPointGeneration(primarycenter, d, p.config.mesh))
        push!(directions, d)
    end

    # Generate the points around the secondary center
    ndirs = Int( ceil( p.num_secondary_points / 2 ) )

    if !isnothing( secondarycenter )
        for i=1:min(ndirs, size(dirs,2) )
            d = dirs[:,i]
            push!(points, PollPointGeneration(secondarycenter, d, p.config.mesh))
            push!(directions, d)

            push!(points, PollPointGeneration(secondarycenter, -d, p.config.mesh))
            push!(directions, -d)
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
