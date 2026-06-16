# Train a forest and score a batch: 100 inliers plus one outlier.
include(joinpath(@__DIR__, "..", "wrappers", "iforest.jl"))
using .IForest

X = vcat(rand(100, 2), [5.0 5.0])          # 100 inliers + 1 outlier
f = IForest.fit(X)                         # n_trees = 100, psi = auto
s = IForest.score(f, X)
println("inlier ", round(s[1], digits=3), "   outlier ", round(s[end], digits=3))
