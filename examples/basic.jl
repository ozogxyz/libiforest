# libiforest from Julia (ccall). Run `make shared` first, then this file.
include(joinpath(@__DIR__, "..", "wrappers", "iforest.jl"))
using .IForest

X = vcat(randn(500, 4), [8.0 8.0 8.0 8.0])    # 500 inliers + 1 outlier

f = IForest.fit(X; n_trees = 100)
s = IForest.score(f, X)
println("inlier mean = ", round(sum(s[1:500]) / 500, digits = 3),
        "   outlier = ", round(s[end], digits = 3))
println("anomalies (score > 0.6): ", sum(IForest.predict(f, X; threshold = 0.6)))
