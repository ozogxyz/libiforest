# libiforest

A small, dependency-free Fortran implementation of the Isolation Forest anomaly
detector (Liu, Ting & Zhou, 2008). The whole library is one file, `iforest.f90`,
and builds to `libiforest.a`.

## Build

    make            # build/libiforest.a and the demo
    make run        # build and run the demo
    make test       # sanity test
    make stress     # stress suite (runtime-checked)
    make OMP=1      # build with OpenMP (parallel scoring)
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
For several independent models or batch/binary output, use the type-based API on
your own `IsolationForest`: `train_forest`, `predict_scores` (continuous), and
`predict` (binary labels by `threshold` or `contamination`).

## C API

A C ABI is exposed via `iso_c_binding` (header `include/iforest.h`):

```c
iforest_t h = iforest_train(X, n, m, 100, 0);  /* row-major X; psi=0 -> auto */
iforest_score(h, X, n, m, scores);             /* (0,1], higher = anomalous */
iforest_predict(h, X, n, m, labels, 0.6);      /* 1 = anomaly */
iforest_free(h);
```

`make cdemo` builds and runs `examples/example.c`. Link against
`build/libiforest.a` with `gfortran` (or `gcc ... -lgfortran -lm`).

## License

MIT — see LICENSE.
