function Poll(p::DSProblem{T})::IterationOutcome where T
    points = GeneratePollPoints(p, p.mesh)
    return EvaluatePoint!(p, points)
end

function GeneratePollPoints(p::DSProblem{T}, ::AbstractMesh)::Vector{Vector{T}} where T
    points = []
    # Mostly implements definition 2.6 from Audet & Dennis 2009

    if !isnothing(p.x)
        dirs = GenerateDirections(p, p.poll, maximal_basis=true)
        append!(points, [p.x + (p.mesh.Δᵐ*p.meshscale.*d) for d in eachcol(dirs)])
    end
    if !isnothing(p.i)
        dirs = GenerateDirections(p, p.poll, maximal_basis=true)
        append!(points, [p.i + (p.mesh.Δᵐ*p.meshscale.*d) for d in eachcol(dirs)])
    end
    return points
end

