using LinearAlgebra
using Random: AbstractRNG, default_rng

export UnitSpherePolling


"""
    UnitSpherePolling

Create `N` directions randomly sampled on the unit sphere. The directions
are passed through the Householder transform after sampling to ensure the
directions form a maximal positive basis for the space.
"""
struct UnitSpherePolling{R <: AbstractRNG} <: AbstractPoll
    # Random number generator to use when generating the polling directions
    rng::R
    maximal_basis::Bool

    function UnitSpherePolling( rng::R = default_rng(); basis = :maximal ) where {R <: AbstractRNG}
        if basis == :maximal
            maximal_basis = true
        elseif basis == :minimal
            maximal_basis = false
        else
            error( "Unknown option for basis type" )
        end

        return new{typeof(rng)}( rng, maximal_basis )
    end
end


"""
    GenerateDirections( prob::T, p::UnitSpherePolling )::Matrix where {T <: AbstractProblem}

Generates the poll directions, using the poll set generation
as described in Audet and Le Digabel 2015 Section 3.4.
"""
function GenerateDirections( prob::T, p::UnitSpherePolling )::Matrix where {T <: AbstractProblem}
    dirs_on_unit_sphere = _sample_unit_sphere( p.rng, prob.N )

    H = _householder_transform( dirs_on_unit_sphere )
    return _form_basis_matrix( prob.N, H, p.maximal_basis )
end


"""
    _sample_unit_sphere( rng::R, N::Int64 ) where {R <: AbstractRNG}

Uses the random number generator `rng` to randomly sample a point on the `N`-dimensional
unit sphere.
"""
function _sample_unit_sphere( rng::R, N::Int64 ) where {R <: AbstractRNG}
    dir = randn( rng, N )
    return dir ./ norm( dir )
end
