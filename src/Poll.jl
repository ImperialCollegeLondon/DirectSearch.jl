"""
    Poll(p::DSProblem{T})::IterationOutcome where T

Generate points and call evaluate on them.
"""
function Poll(p::DSProblem{T})::IterationOutcome where T
    points = GeneratePollPoints(p, p.mesh)
    return EvaluatePoint!(p, points)
end

"""
    GeneratePollPoints(p::DSProblem{T}, ::AbstractMesh)::Vector{Vector{T}} where T

Generate a set of directions with the configured polling algorithm, then return
the set of points these directions give from the incumbent points.
"""
function GeneratePollPoints(p::DSProblem{T}, ::AbstractMesh
                           )::Vector{Vector{T}} where T
    points = []
    dirs = GenerateDirections(p)

    if !isnothing(p.x)
        append!(points, [p.x+(p.mesh.Δᵐ*p.meshscale.*d) for d in eachcol(dirs)])
    end
    if !isnothing(p.i)
        append!(points, [p.i+(p.mesh.Δᵐ*p.meshscale.*d) for d in eachcol(dirs)])
    end

    return points
end

GenerateDirections(p::DSProblem) = GenerateDirections(p, p.poll)
