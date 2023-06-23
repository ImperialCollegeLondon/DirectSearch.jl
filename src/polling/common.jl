"""
    _householder_transform(q)

Apply the Householder transformation to the vector `q`.
"""
function _householder_transform(q)
    nq = norm(q)
    v = q./nq
    return nq^2 .* (I - 2*v*v')
end


"""
   _form_basis_matrix(N::Int, B::Matrix{T}, maximal_basis::Bool) where T

Form the positive basis matrix from `B` for the space of dimension `N`.
The basis is maximal (has 2N entries) when `maximal_basis` is true, and a minimal basis when false.
"""
function _form_basis_matrix(N::Int, B::Matrix{T}, maximal_basis::Bool) where T
    maximal_basis && return [B -B]

    d = zeros(T, N)
    for (i,_) in enumerate(d)
        d[i] = -sum(B[i,:])
    end

    return [B d]
end
