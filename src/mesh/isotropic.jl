#=
Contains functions/type prototypes for the isotropic mesh.
=#

export IsotropicMesh

mutable struct IsotropicMesh{T} <: AbstractMesh
    # Mesh size parameter - The distance between points in the mesh
    Δᵐ::T

    # Poll size parameter - the magnitude of the distance from the incumbent point to the trial points
    Δᵖ::T

    # Integer changed at each iteration to create the mesh size parameter (grows on unsuccessful iterations to shrink the mesh)
    l::Int

    function IsotropicMesh{T}() where T
        mesh = new()

        mesh.l = 0
        mesh.Δᵐ = min(1, 4.0^(-mesh.l))
        mesh.Δᵖ = 2.0^(-mesh.l)

        return mesh
    end 
end

IsotropicMesh() = IsotropicMesh{Float64}()


function MeshSetup!(p::DSProblem, m::IsotropicMesh)
    # No setup to do
end


"""
    MeshUpdate!(m::IsotropicMesh, ::AbstractPoll, result::IterationOutcome, ::Union{Vector,Nothing})

Implements update rule for the isotropic mesh `m` with a generic polling scheme using Audet & Dennis 2006 pg. 23,
with slight modifications to handle progressive barrier constrained optimization from Audet & Dennis 2009 expression 2.4.
"""
function MeshUpdate!(m::IsotropicMesh, ::AbstractPoll, result::IterationOutcome, ::Union{Vector,Nothing})
    if result == Unsuccessful
        m.l += 1
    elseif result == Dominating && m.l > 0
        m.l -= 1
    elseif result == Improving
        m.l == m.l
    end
    
    m.Δᵐ = min(1, 4.0^(-m.l))
    m.Δᵖ = 2.0^(-m.l)
end

"""
    PollPointGeneration(x::Vector{T}, d::Vector{T}, m::IsotropicMesh{T})::Vector{T} where T

Generate a trial point around incumbent point `x`, using direction `d`.
"""
function PollPointGeneration(x::Vector{T}, d::Vector{T}, m::IsotropicMesh{T})::Vector{T} where T
    result = [x+(m.Δᵐ*d) for d in eachcol(dirs)]

    return result
end


"""
    ScaleDirection(m::IsotropicMesh, dir::Vector{T}) where T

Scale the direction vector `dir` using the scaling information in the mesh `m`.
For the isotropic mesh, this operation is a nop because the mesh has no scaling
applied.
"""
function ScaleDirection(::IsotropicMesh, dir::Vector{T}) where T
    # This is a nop on isotropic meshes because they don't have scaling.
    return dir
end
