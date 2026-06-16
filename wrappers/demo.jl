include(joinpath(@__DIR__, "iforest.jl"))
using .IForest

X = randn(500, 4)                 # 500 inliers
X = vcat(X, [8.0 8.0 8.0 8.0])    # + 1 outlier

f = IForest.fit(X)
s = IForest.score(f, X)

println("inlier mean = ", round(sum(s[1:500]) / 500, digits = 3),
        "  outlier = ", round(s[end], digits = 3))
@assert s[end] > sum(s[1:500]) / 500 "outlier should score higher"
println("Julia wrapper OK")
