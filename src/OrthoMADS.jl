using Primes
using LinearAlgebra

export OrthoMADS

"""
    OrthoMADS{T}()

Return an empty LTMADS object. 
"""
mutable struct OrthoMADS{T} <: AbstractPoll
    l::Int64
	Δᵖmin::T
	t₀::Int64
    t::Int64
    tmax::Int64
    OrthoMADS(N) = OrthoMADS{Float64}(N)
    function OrthoMADS{T}(N) where T l = 0
        M = new()
        #Initialise as the Nth prime
        M.tmax = M.t = M.t₀ = prime(N)
        M.l = 0
        M.Δᵖmin = 1.0
        return M
    end
end

"""
    MeshUpdate!(mesh::Mesh, improvement_found::Bool)

Implements LTMADS update rule from Audet & Dennis 2006 pg. 203 adapted for progressive 
barrier constraints with Audet & Dennis 2009 expression 2.4
"""
function MeshUpdate!(m::Mesh{T}, o::OrthoMADS{T}, result::IterationOutcome) where T
    if result == Unsuccessful
        o.l += 1
    elseif result == Dominating
        o.l -= 1
    elseif result == Improving
        o.l = o.l
    end

    m.Δᵐ = min(1, 4.0^(-o.l))
    m.Δᵖ = 2.0^(-o.l)

    if m.Δᵖ < o.Δᵖmin
        o.Δᵖmin = m.Δᵖ
        o.t = o.l + o.t₀
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
    H = GenerateBasis(N, DG.t, DG.l)
	return hcat(H, -H)
end

function GenerateBasis(N::Int64, t::Int64, l::Int64)
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
    #A function that describes a family of directions
    q = AdjustedHaltonFamily(halt)
    #Need to find the argument, α, of q that maximises l2 norm of result, s.t. it is ≤2^(|l|/2)
    #∃ optimal solution satisfying α ≥ 2^(|l|/2)/√n -0.5, ∴ use as starting point
    α = (2^(abs(l)/2)/sqrt(n)) - 0.5
    
    α = bad_argmax(α, x -> norm(q(x)), 2^(abs(l)/2))
    
    return q(α)
end

function AdjustedHaltonFamily(halt)
    d = 2 * halt .- 1
    q(α) = round.(α .* d ./ norm(d))
    return q
end

#TODO use a better defined algorithm for this operation
#(some kind of numerical line search?)
function bad_argmax(x, f, lim; iter_lim = 15)
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

