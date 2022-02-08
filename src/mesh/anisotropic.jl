#=
Contains functions/type prototypes for the anisotropic mesh.
=#

export AnisotropicMesh

#= Mesh =#
# Meshes should be subtypes of AbstractMesh that contain all variables
# that define a mesh. An effort should be make to follow the naming
# conventions established in existing methods in order to give compatibility
# between methods.


mutable struct AnisotropicMesh{T} <: AbstractMesh
    # Number of directions in the mesh
    N::Int

    # Minimum mesh size vector allowed for the mesh
    δ_min::Vector{T}

    # The number of digits used to represent each direction in the mesh
    digits::Vector{Union{Int, Nothing}}

    # Integer changed at each iteration (grows on unsuccessful iterations to shrink the mesh)
    l::Int

    # Mesh size vector containing the mesh size parameter for each direction in the mesh
    δ::Vector{T}

    # Mesh size vector from the intial iteration
    δ⁰::Vector{T}

    # Poll size vector containing the poll size parameter for each direction in the mesh
    Δ::Vector{T}

    # Ratio vector containing the ratio between the poll size and mesh size for each direction in the mesh
    ρ::Vector{T}

    # Minimum ratio allowed for the mesh
    ρ_min::T

    # Magnitude vector for the magnitude portion of the controlled decimal mesh
    a::Vector{Int}

    # Exponent vector for the Exponential portion of the controlled decimal mesh
    b::Vector{Int}

    # Initial magnitude vector
    a⁰::Vector{Int}

    # Initial exponent vector
    b⁰::Vector{Int}

    # Anisotopy trigger paramater vector - used to determine if the successful direction was "active" in a mesh direction
    aₜ::T
    only_granular::Bool

    function AnisotropicMesh{T}(N::Int64) where T
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

AnisotropicMesh(N::Int64) = AnisotropicMesh{Float64}(N)


"""
    MeshSetup!(p::DSProblem, m::AnisotropicMesh)

Set up the anisotropic mesh with the parameters defined for problem.
"""
function MeshSetup!(p::DSProblem, m::AnisotropicMesh)
    m.δ_min = p.granularity
    m.digits = map(get_decimal_places, p.granularity)
    m.only_granular = all(p.granularity .> 0)

    _init_a_and_b!(p, m)

    _update_mesh_parameters!(m)
    m.δ⁰ = copy(m.δ)
end

"""
    MeshUpdate!(mesh::AnisotropicMesh, ::AbstractPoll, result::IterationOutcome, dir::Union{Vector,Nothing})

Implements update rule from Audet, Le Digabel & Tribes 2019 adapted for progressive
barrier constraints with Audet & Dennis 2009 expression 2.4.

`dir` is the direction of success of the iteration, equal to `nothing`, if there is none.
"""
function MeshUpdate!(m::AnisotropicMesh, ::AbstractPoll, result::IterationOutcome, dir::Union{Vector,Nothing})
    if result == Unsuccessful
        for i=1:m.N
            _decrease_a_and_b!(m, i)
        end
        m.l -= 1
        _update_mesh_parameters!(m)
    elseif result == Dominating
        for i=1:m.N
            if dir === nothing || (abs(dir[i])/m.ρ[i] > m.aₜ) || (m.δ_min[i] == 0  && m.δ[i] < m.δ⁰[i] && m.ρ[i] > m.ρ_min^2)
                _increase_a_and_b!(m, i)
            end
        end
        m.l += 1
        _update_mesh_parameters!(m)
    end
end

"""
    ScaleDirection(p::AnisotropicMesh, dir::Vector{T}) where T

Scale the direction vector `dir` using the scaling information in the mesh `m`.
On Anistropic meshes, this uses the vector `ρ`, which is the mesh ratio.
"""
function ScaleDirection(m::AnisotropicMesh{T}, dir::Vector{T}) where T
    infNorm = maximum(abs.(dir))

    if infNorm == 0
        error("Unexpected error. Poll algorithm generated a direction equal to zero.")
    end

    d_scaled = dir ./ infNorm

    return round.(d_scaled .* m.ρ)
end

"""
    PollPointGeneration(x::Vector{T}, d::Vector{T}, m::AnisotropicMesh{T})::Vector{T} where T

Generate a trial point around incumbent point `x`, using direction `d`, while taking into account
the variable granularity.
"""
function PollPointGeneration(x::Vector{T}, d::Vector{T}, m::AnisotropicMesh{T})::Vector{T} where T
    result = []

    for i=1:length(x)
        single_result = x[i] + (d[i] * m.δ[i])
        push!(result, isnothing(m.digits[i]) ? single_result : round(single_result, digits=m.digits[i]))
    end
    return result
end


"""
    _update_mesh_parameters!(m::AnisotropicMesh)

Sets the mesh parameters: mesh size vector δ, poll size vector Δ, and ratio vector ρ.
"""
function _update_mesh_parameters!(m::AnisotropicMesh)
    _update_mesh_size_vector!(m)
    _update_poll_size_vector!(m)
    _update_ratio_vector!(m)
end

"""
    _update_mesh_size_vector!(m::AnisotropicMesh)

Sets the mesh size vector δ.
"""
function _update_mesh_size_vector!(m::AnisotropicMesh)
    for i = 1:m.N
        m.δ[i] = 10.0^(m.b[i] - abs(m.b[i] - m.b⁰[i]))

        if m.δ_min[i] > 0
            m.δ[i] = m.δ_min[i] * max.(1, m.δ[i])
        end
    end
end

"""
    _update_poll_size_vector!(m::AnisotropicMesh)

Sets the poll size vector Δ.
"""
function _update_poll_size_vector!(m::AnisotropicMesh)
    for i = 1:m.N
        m.Δ[i] = m.a[i] * (10.0 ^ m.b[i])

        if m.δ_min[i] > 0
            m.Δ[i] = m.δ_min[i] * m.Δ[i]
        end
    end
end

"""
    _update_ratio_vector!(m::AnisotropicMesh)

Sets the ratio vector ρ.
"""
function _update_ratio_vector!(m::AnisotropicMesh{T}) where T
    m.ρ = m.Δ ./ m.δ

    if any(m.δ_min .== 0)
        m.ρ_min = minimum(m.ρ[m.δ_min .== 0])
    else
        m.ρ_min = typemin(T)
    end
end

"""
    _init_a_and_b!(p::DSProblem, m::AnisotropicMesh)

Initializes the parameters `a` and `b`, which define the mesh and poll sizes.
"""
function _init_a_and_b!(p::DSProblem, m::AnisotropicMesh)
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

"""
    _increase_a_and_b!(m::AnisotropicMesh, i::Int)

Modify the values of `a` and `b` inside the anisotropic mesh `m` using the rules from [1] to increase the mesh size parameter.

[1] C. Audet, S. Le Digabel, and C. Tribes, ‘The Mesh Adaptive Direct Search Algorithm for Granular and Discrete Variables’,
    SIAM J. Optim., vol. 29, no. 2, pp. 1164–1189, Jan. 2019, doi: 10.1137/18M1175872.
"""
function _increase_a_and_b!(m::AnisotropicMesh, i::Int)
    if m.a[i] == 1
        m.a[i] = 2
    elseif m.a[i] == 2
        m.a[i] = 5
    else
        m.a[i] = 1
        m.b[i] += 1
    end
end

"""
    _decrease_a_and_b!(m::AnisotropicMesh, i::Int, dir::Union{Vector,Nothing})

Modify the values of `a` and `b` inside the anisotropic mesh `m` using the rules from [1] to decrease the mesh size parameter.

[1] C. Audet, S. Le Digabel, and C. Tribes, ‘The Mesh Adaptive Direct Search Algorithm for Granular and Discrete Variables’,
    SIAM J. Optim., vol. 29, no. 2, pp. 1164–1189, Jan. 2019, doi: 10.1137/18M1175872.
"""
function _decrease_a_and_b!(m::AnisotropicMesh, i::Int)
    if m.a[i] == 1
        if m.b[i] > 0 || m.δ_min[i] == 0
            m.a[i] = 5
            m.b[i] -= 1
        end
    elseif m.a[i] == 2
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
