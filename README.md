# libiforest

A small, dependency-free Fortran implementation of the Isolation Forest anomaly
detector (Liu, Ting & Zhou, 2008). The whole library is one file, `iforest.f90`,
and builds to `libiforest.a`.

## Build

    make        # build/libiforest.a and the demo
    make test
    make run
    make clean

## Use

```fortran
use iforest, only: dp, fit, get_score

real(dp) :: X(n, m), point(m), score

call fit(X, n, m)               ! X is n samples by m features
call get_score(point, m, score) ! score in (0,1], higher = more anomalous
```

`fit` holds one global model (not thread-safe; a refit replaces it) and takes
optional `n_trees` (default 100) and `psi` subsample size (default `min(256, n)`).
For several independent models, call `train_forest` / `predict_scores` on your
own `IsolationForest` instance instead.

## License

MIT — see LICENSE.
