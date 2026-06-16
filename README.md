# libiforest

A small, dependency-free Fortran implementation of the Isolation Forest anomaly
detector (Liu, Ting & Zhou, 2008). The whole library is one file, `iforest.f90`,
and builds to `libiforest.a`.

## Build

    make            # build/libiforest.a and the demo
    make run        # build and run the demo
    make test       # sanity test
    make stress     # stress suite (runtime-checked)
    make cdemo      # build and run the C example
    make shared     # build/libiforest.so (C ABI / Python / Julia)
    make OMP=1      # build with OpenMP (parallel train + score)
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

## Thread safety

The type-based API and the C ABI are thread-safe per object: give each thread its
own forest/handle and they share nothing. Scoring one shared forest from several
threads is also fine (read-only). Only the singleton layer (`fit`/`get_score`/
`release`) is not — it uses one hidden global model. See `examples/threads.c`.

## C API

A C ABI is exposed via `iso_c_binding` (header `include/iforest.h`):

```c
iforest_t h = iforest_train(X, n, m, 100, 0);  /* row-major X; psi=0 -> auto */
iforest_score(h, X, n, m, scores);             /* (0,1], higher = anomalous */
iforest_predict(h, X, n, m, labels, 0.6);      /* 1 = anomaly */
iforest_free(h);
```

### Linking

Static (no runtime dependency on libiforest):

    gcc app.c -Iinclude build/libiforest.a -lgfortran -lm -o app
    # add -lgomp if the library was built with OMP=1

Dynamic:

    make shared
    gcc app.c -Iinclude -Lbuild -liforest -o app
    LD_LIBRARY_PATH=build ./app

Worked examples: `make cdemo` / `make cdemo-static` / `make cdemo-dyn`, and
`make threads` for concurrent per-handle scoring.

### Python and Julia

`make shared` builds `build/libiforest.so`; thin wrappers live in `wrappers/`:

```python
from wrappers.iforest import IsolationForest
f = IsolationForest().fit(X)          # X: (n, m) array
s = f.score(X)
lab = f.predict(X, threshold=0.6)
```

Julia is the same shape — `wrappers/iforest.jl` (then `julia wrappers/demo.jl`).

## License

MIT — see LICENSE.
