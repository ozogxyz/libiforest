# ccall wrapper over libiforest's C ABI. Build the shared lib first: make shared.
module IForest

const LIB = abspath(joinpath(@__DIR__, "..", "build", "libiforest.so"))

mutable struct Forest
    h::Ptr{Cvoid}
end

# X is (n_samples, n_features). Julia is column-major, so transpose(X) materialized
# as (m, n) has exactly the row-major layout the C ABI wants (X[i*m + j]).
function fit(X::AbstractMatrix{<:Real}; n_trees::Integer=100, psi::Integer=0)
    n, m = size(X)
    Xt = Matrix{Float64}(transpose(X))
    h = ccall((:iforest_train, LIB), Ptr{Cvoid},
              (Ptr{Float64}, Cint, Cint, Cint, Cint), Xt, n, m, n_trees, psi)
    f = Forest(h)
    finalizer(free, f)
    return f
end

function score(f::Forest, X::AbstractMatrix{<:Real})
    n, m = size(X)
    Xt = Matrix{Float64}(transpose(X))
    s = Vector{Float64}(undef, n)
    ccall((:iforest_score, LIB), Cvoid,
          (Ptr{Cvoid}, Ptr{Float64}, Cint, Cint, Ptr{Float64}), f.h, Xt, n, m, s)
    return s
end

function predict(f::Forest, X::AbstractMatrix{<:Real}; threshold::Real=0.5)
    n, m = size(X)
    Xt = Matrix{Float64}(transpose(X))
    lab = Vector{Cint}(undef, n)
    ccall((:iforest_predict, LIB), Cvoid,
          (Ptr{Cvoid}, Ptr{Float64}, Cint, Cint, Ptr{Cint}, Float64),
          f.h, Xt, n, m, lab, Float64(threshold))
    return Int.(lab)
end

function free(f::Forest)
    if f.h != C_NULL
        ccall((:iforest_free, LIB), Cvoid, (Ptr{Cvoid},), f.h)
        f.h = C_NULL
    end
end

end # module
