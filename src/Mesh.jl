#=
Contains functions/type prototypes for the mesh.
=#

#= Mesh =#
#Subtypes should contain all variables that define a mesh.
#Should make an effort to follow the naming conventions established
#in existing methods in order to give compatibility between methods
abstract type AbstractMesh end

mutable struct Mesh{T} <: AbstractMesh
    N::Int

    δ_min::Vector{T}
    digits::Vector{Union{Int, Nothing}}

    l::Int
    δ::Vector{T}
    δ⁰::Vector{T}
    Δ::Vector{T}
    ρ::Vector{T}
    ρ_min::T
    a::Vector{Int}
    b::Vector{Int}
    a⁰::Vector{Int}
    b⁰::Vector{Int}

    is_anisotropic::Bool
    aₜ::T
    only_granular::Bool

    # Override constructor for different default meshes for
    # different poll techniques.
    Mesh(N::Int64) = Mesh{Float64}(N)
    function Mesh{T}(N::Int64) where T
        mesh = new()

        mesh.N = N

        mesh.aₜ = 0.1

        mesh.l = 0
        mesh.a⁰ = Vector{Int}(undef, N)
        mesh.b⁰ = Vector{Int}(undef, N)
        mesh.a = Vector{Int}(undef, N)
        mesh.b = Vector{Int}(undef, N)
        mesh.δ = Vector{T}(undef, N)
        mesh.Δ = Vector{T}(undef, N)
        return mesh
    end
end

"""
    MeshSetup!(p::DSProblem)

Sets up the Mesh with the parameters defined for problem.
"""
MeshSetup!(p::DSProblem) = MeshSetup!(p, p.config.mesh)
function MeshSetup!(p::DSProblem, m::Mesh)
    m.is_anisotropic = p.config.poll isa OrthoMADS

    m.δ_min = p.granularity
    m.digits = map(get_decimal_places, p.granularity)
    m.only_granular = all(p.granularity .> 0)

    init_a_and_b!(p, m)

    SetMeshParameters!(m)
    m.δ⁰ = copy(m.δ)
end

"""
    MeshUpdate!(mesh::Mesh, ::AbstractPoll, result::IterationOutcome, dir::Union{Vector,Nothing})

Implements update rule from Audet, Le Digabel & Tribes 2019 adapted for progressive
barrier constraints with Audet & Dennis 2009 expression 2.4.

`dir` is the direction of success of the iteration, equal to `nothing`, if there is none.
"""
function MeshUpdate!(m::Mesh, ::AbstractPoll, result::IterationOutcome, dir::Union{Vector,Nothing})
    if result == Unsuccessful
        for i=1:m.N
            decrease_a_and_b!(m, i)
        end
        m.l -= 1
        SetMeshParameters!(m)
    elseif result == Dominating
        for i=1:m.N
            increase_a_and_b!(m, i, dir)
        end
        m.l += 1
        SetMeshParameters!(m)
    end
end

"""
    SetMeshParameters!(m::Mesh)

Sets the mesh parameters: mesh size vector δ, poll size vector Δ, and ratio vector ρ.
"""
function SetMeshParameters!(m::Mesh)
    SetMeshSizeVector!(m)
    SetPollSizeVector!(m)
    SetRatioVector!(m)
end

"""
    SetMeshSizeVector!(m::Mesh)

Sets the mesh size vector δ.
"""
function SetMeshSizeVector!(m::Mesh)
    for i = 1:m.N
        m.δ[i] = 10.0^(m.b[i] - abs(m.b[i] - m.b⁰[i]))

        if m.δ_min[i] > 0
            m.δ[i] = m.δ_min[i] * max.(1, m.δ[i])
        end
    end
end

"""
    SetPollSizeVector!(m::Mesh)

Sets the poll size vector Δ.
"""
function SetPollSizeVector!(m::Mesh)
    for i = 1:m.N
        m.Δ[i] = m.a[i] * (10.0 ^ m.b[i])

        if m.δ_min[i] > 0
            m.Δ[i] = m.δ_min[i] * m.Δ[i]
        end
    end
end

"""
    SetRatioVector!(m::Mesh)

Sets the ratio vector ρ.
"""
function SetRatioVector!(m::Mesh{T}) where T
    m.ρ = m.Δ ./ m.δ

    if any(m.δ_min .== 0)
        m.ρ_min = minimum(m.ρ[m.δ_min .== 0])
    else
        m.ρ_min = typemin(T)
    end
end

"""
    init_a_and_b!(p::DSProblem, m::Mesh)

Initializes the parameters `a` and `b`, which define the mesh and poll sizes.
"""
function init_a_and_b!(p::DSProblem, m::Mesh)
    for i = 1:p.N
        α = get_poll_size_estimate(p.user_initial_point[i], p.lower_bounds[i], p.upper_bounds[i])

        if m.δ_min[i] > 0
            α_scaled = α/m.δ_min[i]
        else
            α_scaled = α
        end

        b⁰ = floor(Int, log10(α_scaled))

        # b cannot has to be nonnegative for granular indexes
        if b⁰ < 0 && m.δ_min[i] > 0
            b⁰ = 0
        end

        # the NOMAD way
        # if b⁰ < 0
        #     b⁰ = 0
        # end

        a⁰ = α_scaled / (10.0^b⁰)

        if a⁰ < 1.5
            a⁰ = 1
        elseif a⁰ < 3.5
            a⁰ = 2
        else
            a⁰ = 5
        end

        m.a⁰[i] = a⁰
        m.b⁰[i] = b⁰

        m.a[i] = a⁰
        m.b[i] = b⁰
    end
end

"""
    get_poll_size_estimate(x⁰::T, lower_bound::Union{T,Nothing}, upper_bound::Union{T,Nothing})::T where T

Calculates the initial poll size, as given in Audet, Le Digabel & Tribes 2019 expression 3.3,
using the initial point and variable bounds, if specified.
"""
function get_poll_size_estimate(x⁰::T, lower_bound::Union{T,Nothing}, upper_bound::Union{T,Nothing})::T where T
    if !(lower_bound === nothing) && !(upper_bound === nothing) && (lower_bound < upper_bound)
        (upper_bound - lower_bound)/10
    else
        if !(lower_bound === nothing) && (upper_bound === nothing)
            finite_bound = lower_bound
        elseif !(upper_bound === nothing) && (lower_bound === nothing)
            finite_bound = upper_bound
        else
            finite_bound = nothing
        end

        if !(finite_bound === nothing) && !(finite_bound === x⁰)
            abs(x⁰ - finite_bound)/10
        elseif !(x⁰ == 0)
            abs(x⁰)/10
        else
            1
        end
    end
end

function increase_a_and_b!(m::Mesh, i::Int, dir::Union{Vector,Nothing})
    if dir === nothing || !m.is_anisotropic || (abs(dir[i])/m.ρ[i] > m.aₜ) || (m.δ_min[i] == 0  && m.δ[i] < m.δ⁰[i] && m.ρ[i] > m.ρ_min^2)
        if m.a[i] === 1
            m.a[i] = 2
        elseif m.a[i] === 2
            m.a[i] = 5
        else
            m.a[i] = 1
            m.b[i] += 1
        end
    end
end

function decrease_a_and_b!(m::Mesh, i::Int)
    if m.a[i] === 1
        if m.b[i] > 0 || m.δ_min[i] == 0
            m.a[i] = 5
            m.b[i] -= 1
        end
    elseif m.a[i] === 2
        m.a[i] = 1
    else
        m.a[i] = 2
    end
end

function get_decimal_places(granularity)::Union{Int, Nothing}
    granularity == 0 && return nothing

    str_split = split(string(granularity), ".")

    if length(str_split) == 1 || (length(str_split[2]) == 1 && str_split[2][1] == '0')
        return 0
    else
        return length(str_split[2])
    end
end
