using Primes
using LinearAlgebra

export OrthoMADS

"""
    OrthoMADS(N::Int)

Return an empty OrthoMADS object. `N` must match the dimension of the
problem that this stage is being given to.

OrthoMADS uses Halton sequences to generate an orthogonal basis of
directiosn for the poll step. This is a deterministic process, unlike
(`LTMADS`)[@ref].
"""
mutable struct OrthoMADS{T,F} <: AbstractPoll
    l::F
    Δᵖmin::T
    t₀::F
    t::F
    tmax::F
    OrthoMADS(N::Int) = OrthoMADS{Float64,Int64}(N)
    function OrthoMADS{T,F}(N::F) where {T,F}
        M = new()
        #Initialise as the Nth prime
        M.tmax = M.t = M.t₀ = prime(N)
        M.l = 0
        M.Δᵖmin = 1.0
        return M
    end
end

"""
    MeshUpdate!(mesh::Mesh, o::OrthoMADS, result::IterationOutcome)

Implements the OrthoMads update rules.
"""
function MeshUpdate!(m::Mesh, o::OrthoMADS, result::IterationOutcome)
    if result == Unsuccessful
        m.l += 1
    elseif result == Dominating
        m.l -= 1
    elseif result == Improving
        m.l = m.l
    end

    #Note that this replicates the operation done in the MeshUpdate!(::Mesh) function,
    #but it necessary for the internal logic.
    m.Δᵐ = min(1, 4.0^(-m.l))
    m.Δᵖ = 2.0^(-m.l)

    if m.Δᵖ < o.Δᵖmin
        o.Δᵖmin = m.Δᵖ
        o.t = m.l + o.t₀
    else
        o.t = 1 + o.tmax
    end

    if o.t > o.tmax
        o.tmax = o.t
    end
end


"""
    GenerateDirections(p::DSProblem{T}, DG::LTMADS{T})::Vector{Vector{T}}

Generates columns and forms a basis matrix for direction generation. 
"""
(GenerateDirections(p::AbstractProblem, DG::OrthoMADS{T})::Matrix{T}) where T = 
    GenerateDirections(p.N, DG)

function GenerateDirections(N::Int64, DG::OrthoMADS{T})::Matrix{T} where T
    H = GenerateOMBasis(N, DG.t, DG.l)
	return hcat(H, -H)
end

function GenerateOMBasis(N::Int64, t::Int64, l::Int64)
	h = Halton(N, t)    
	q = AdjustedHalton(h, N, l)
	return HouseholderTransform(q)
end

function Halton(N::Int64, t::Int64)
    p = map(prime, 1:N)
    return map(p -> HaltonEntry(p,t), p)
end

function HaltonEntry(p,t)
    u = 0
    a_r = HaltonCoefficient(p,t)
    for (r,a) in enumerate(a_r)
        u += a/(p^r) #note that the equation is a/p^r+1, but julia indexes from 1
    end
    return u
end

function HaltonCoefficient(p,t)
    t==0 && return []
    #Maximum non-zero value of r
    r_max = floor(Int64, log(p, t))
    #Need to give values for 0:r_max
    a = zeros(Int(r_max+1))
    t_local = t
    for r in r_max:-1:0
        t_local == 0 && break
        a[r+1] = floor(t_local/p^r)
        t_local -= p^r * a[r+1]
    end
    return a   
end


function AdjustedHalton(halt, n, l)
    q = AdjustedHaltonFamily(halt)
    α = (2^(abs(l)/2)/sqrt(n)) - 0.5
    
    α = argmax(α, x -> norm(q(x)), 2^(abs(l)/2))
    
    return q(α)
end

function AdjustedHaltonFamily(halt)
    d = 2 * halt .- 1
    q(α) = round.(α .* d ./ norm(d))
    return q
end

#TODO use a better defined algorithm for this operation
#(some kind of numerical line search?)
function argmax(x, f, lim; iter_lim = 15)
    bump = 1
    iter = 1
    
    while iter < iter_lim
        t = x + bump
        if lim >= f(t)
            x = t
        else
            bump /= 2
        end
        iter += 1
    end
    return x
end

function HouseholderTransform(q)
    nq = norm(q)
    v = q./nq
    return nq^2 .* (I - 2*v*v')
end

