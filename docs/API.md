# libiforest API reference

Isolation Forest (Liu, Ting & Zhou, 2008). Train a forest on a data matrix, then
get a continuous anomaly score (or a binary label) for each row.

## Concepts

**Data layout.** A dataset is `n` samples by `m` features.
- Fortran: a `real(dp)` array `X(n, m)` — sample per row, feature per column.
- C / Python: row-major, `X[i*m + j]` is sample `i`, feature `j`.
- Julia: pass an `(n, m)` matrix; the wrapper transposes it for you.

**Score.** `predict_scores` returns a value in `(0, 1]` per sample: about `0.5`
for ordinary points, approaching `1` for points isolated in few splits. There is
no sign flip — higher always means more anomalous.

**Labels.** `predict` turns scores into `1` (anomaly) / `0` (normal), either at a
fixed `threshold` or by flagging the top `contamination` fraction.

**Parameters.** `n_trees` (default 100) and `psi`, the per-tree subsample size
(default `min(256, n)`). These are the two standard Isolation Forest knobs.

**Thread safety.** Every forest / handle is independent and holds no global state.
Use one per thread, or share one read-only for concurrent scoring — both are safe.

---

## Fortran

```fortran
use iforest, only: dp, IsolationForest, train_forest, predict_scores, predict, free_forest
```

### `type(IsolationForest)`
An opaque trained model. Declare one, train it, score with it, free it.

### `train_forest(forest, X, n_samples [, psi] [, n_trees])`
- `type(IsolationForest), intent(inout) :: forest`
- `real(dp), intent(in) :: X(:,:)` — `(n_samples, m)`
- `integer, intent(in) :: n_samples`
- `integer, intent(in), optional :: psi` — subsample size, default `min(256, n_samples)`
- `integer, intent(in), optional :: n_trees` — default `100`

Trains `forest`, replacing any previous model. Builds trees in parallel when
compiled with `-fopenmp`. `error stop` if `n_samples < 2`, `psi` outside
`[2, n_samples]`, or `n_trees < 1`.

### `predict_scores(forest, X, n_samples, scores)`
- `real(dp), intent(out) :: scores(:)` — filled `scores(1:n_samples)`

Continuous anomaly score per row of `X`. Parallel scoring under `-fopenmp`.

### `predict(forest, X, n_samples, labels [, threshold] [, contamination])`
- `integer, intent(out) :: labels(:)` — `1` = anomaly, `0` = normal
- `real(dp), intent(in), optional :: threshold` — flag `score >= threshold`
- `real(dp), intent(in), optional :: contamination` — flag the top fraction

With neither option, `threshold` defaults to `0.5`. If both are given, `threshold`
wins.

### `free_forest(forest)`
Releases the model. Safe to call on an already-freed forest.

---

## C

```c
#include "iforest.h"   /* -Iinclude */
```

Link statically against `build/libiforest.a` (with `-lgfortran -lm`, plus `-lgomp`
if built `OMP=1`) or dynamically against `build/libiforest.so`.

### `iforest_t iforest_train(const double *X, int n, int m, int n_trees, int psi)`
Train on row-major `X` (`n` x `m`). `n_trees <= 0` -> 100; `psi <= 0` -> `min(256, n)`.
Returns a handle; free it with `iforest_free`.

### `void iforest_score(iforest_t h, const double *X, int n, int m, double *scores)`
Fill `scores[0..n-1]` with continuous scores for row-major `X`.

### `void iforest_predict(iforest_t h, const double *X, int n, int m, int *labels, double threshold)`
Fill `labels[0..n-1]` with `1` if `score >= threshold`, else `0`.

### `void iforest_free(iforest_t h)`
Release a handle.

---

## Python — `wrappers/iforest.py`

Needs `build/libiforest.so` (`make shared`).

```python
from iforest import IsolationForest

f = IsolationForest(n_trees=100, psi=0).fit(X)   # X: (n, m) array-like
s = f.score(X)                                   # ndarray (n,), higher = anomalous
labels = f.predict(X, threshold=0.6)             # ndarray (n,) of 0/1
```

`fit` copies `X` to a contiguous `float64` array. The handle is freed on garbage
collection.

---

## Julia — `wrappers/iforest.jl`

Needs `build/libiforest.so` (`make shared`).

```julia
include("wrappers/iforest.jl"); using .IForest

f = IForest.fit(X; n_trees = 100, psi = 0)   # X :: (n, m) matrix
s = IForest.score(f, X)                       # Vector{Float64}
labels = IForest.predict(f, X; threshold = 0.6)
IForest.free(f)                               # also runs as a finalizer
```
