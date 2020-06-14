using Random
using LinearAlgebra

export LTMADS

"""
    LTMADS()

Return an empty LTMADS object. 

LTMADS is a poll stage that creates a set of directions based
on a semi-randomly generated lower triangular matrix. This randomness
means that several runs of the algorithm may be needed to find a minimum.
"""
mutable struct LTMADS{T} <: AbstractPoll
    b::Dict{T,Vector{T}}
    i::Dict{T,Int}
    maximal_basis::Bool
    LTMADS(;kwargs...) = LTMADS{Float64}(;kwargs...)
    function LTMADS{T}(;maximal_basis=true) where T
        g = new()
        g.b = Dict{T, Vector{T}}()
        g.i = Dict{T, Int}()
        g.maximal_basis=maximal_basis
        return g
    end
end


"""
    GenerateDirections(p::DSProblem{T}, DG::LTMADS{T})::Vector{Vector{T}}

Generates columns and forms a basis matrix for direction generation. 
"""
function GenerateDirections(p::AbstractProblem, DG::LTMADS{T})::Matrix{T} where T
    B = LT_basis_generation(p.mesh, p.N, DG)
    Dₖ = form_basis_matrix(p.N, B, DG.maximal_basis)

    return Dₖ
end

function form_basis_matrix(N::Int, B::Matrix{T}, max_basis::Bool) where T
    max_basis && return [B -B]

    d = zeros(T, N)
    for (i,_) in enumerate(d)
        d[i] = -sum(B[i,:])
    end

    return [B d]
end

function LT_basis_generation(m::Mesh, N::Int, DG::LTMADS{T}) where T
    b, i = b_l_generation(DG.b, DG.i, m.l, N)

    L = L_generation(N, m.l)

    B = B_generation(N, i, b, L)
    
    B′ = B′_generation(B, N)

    return B′
end

function B′_generation(B, N; perm=shuffle(1:N)) 
    B′ = zeros(N,N)
    for (i,e) in enumerate(eachcol(B))
        B′[:,perm[i]] = e
    end
    return B′
end

function b_l_generation(b::Dict{T,Vector{T}}, i::Dict{T,Int}, l::Int, N::Int) where T
    if !haskey(b, l)
        i[l] = rand(1:N)
        b[l] = zeros(T, N)
        
        for j in 1:N
            if j == i[l]
                b[l][j] = rand([-2^l, 2^l])
            else
                b[l][j] = rand(-2^l+1:2^l-1)
            end
        end
    end
    return b[l], i[l]
end

function L_generation(N, l)
    L = zeros(N-1,N-1)

    for i=1:N-1, j=1:N-1
        if j==i
            L[i,j] = rand([2^l, -2^l])
        elseif j < i
            L[i,j] = rand(1-2^l:-1+2^l)
        end
    end
    
    return L
end

function B_generation(N, i, b, L; perm=shuffle(setdiff(1:N, i)))
    B = zeros(N,N-1)
    for (i,e) in enumerate(eachrow(L))
        B[perm[i],:] = e
    end
    B = [B b]
    return B
end

