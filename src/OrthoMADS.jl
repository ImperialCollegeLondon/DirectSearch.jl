using Primes
using LinearAlgebra

export OrthoMADS

"""
    OrthoMADS{T}()

Return an empty LTMADS object. 
"""
mutable struct OrthoMADS{T} <: AbstractPoll
    l::Int64
    Δᵖ::Float64
    Δᵐ::Float64
end

"""
    MeshUpdate!(mesh::Mesh, improvement_found::Bool)

Implements LTMADS update rule from Audet & Dennis 2006 pg. 203 adapted for progressive 
barrier constraints with Audet & Dennis 2009 expression 2.4
"""
function MeshUpdate!(m::Mesh{T}, ::LTMADS{T}, result::IterationOutcome) where T
    if result == Unsuccessful
        m.l += 1
    elseif result == Dominating
        m.l -= 1
    elseif result == Improving
        m.l = m.l
    end
    m.Δᵐ = min(1, 4.0^(-m.l))
    m.Δᵖ = 2.0^(-m.l)
end


"""
    GenerateDirections(p::DSProblem{T}, DG::LTMADS{T})::Vector{Vector{T}}

Generates columns and forms a basis matrix for direction generation. 
"""
function GenerateDirections(p::AbstractProblem, DG::LTMADS{T})::Matrix{T} where T
	h = Halton(p.N, t)    
	q = AdjustedHalton(h, p.N, DG.l)
	H = HouseholderTransform(q)
	return hcat(H, -H)
end


function Halton(n, t)
    p = map(prime, 1:n)
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


function AdjustedHaltonFamily(halt)
    d = 2 * halt .- 1
    q(α) = round.(α .* d ./ norm(d))
    return q
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

#should find some numerical line search for this
function bad_argmax(x, f, lim; iter_lim = 10)
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

