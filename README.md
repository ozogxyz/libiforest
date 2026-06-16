# libiforest

Isolation Forest anomaly detection as a small, dependency-free Fortran library —
one file (`iforest.f90`), builds to `libiforest.a`, callable from Fortran, C, and
Julia. Faster and far leaner than scikit-learn's `IsolationForest`, with no Python
or BLAS in the loop, so it drops straight into existing Fortran / HPC / native
data pipelines.

## Quickstart (Fortran)

```fortran
use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest

type(IsolationForest) :: forest
real(dp) :: X(n, m), scores(n)

call train_forest(forest, X, n)            ! 100 trees, psi = min(256, n)
call predict_scores(forest, X, n, scores)  ! score in (0,1], higher = more anomalous
call free_forest(forest)
```

You own the `forest`: train it, score with it, free it. For binary labels,
threshold the scores (`scores >= t`). Each forest is independent, so one per
thread is safe (see `examples/threads.c`). More in [examples/](examples/) and the
[API reference](docs/API.md).

## From C and Julia

```c
iforest_t h = iforest_train(X, n, m, 100, 0);   /* row-major X */
iforest_score(h, X, n, m, scores);
iforest_free(h);
```

```julia
include("wrappers/iforest.jl"); using .IForest
s = IForest.score(IForest.fit(X), X)
```

## Build

    make            # libiforest.a + the demo (build/iforest)
    make examples   # build and run the Fortran examples
    make test       # quick sanity test
    make stress     # stress suite (runtime-checked)
    make shared     # libiforest.so (for C / Julia)
    make OMP=1      # parallel training and scoring (OpenMP)
    make clean

Linking C, by hand — static:

    gcc app.c -Iinclude build/libiforest.a -lgfortran -lm -o app   # add -lgomp if OMP=1

dynamic:

    gcc app.c -Iinclude -Lbuild -liforest -o app && LD_LIBRARY_PATH=build ./app

Worked C targets: `make cdemo` / `cdemo-static` / `cdemo-dyn` / `threads`.

## Performance

100k x 16, 100 trees, single core, vs scikit-learn 1.9 (`n_jobs=1`):

| | scikit-learn | libiforest |
|---|---|---|
| train | 0.22 s | **0.10 s** |
| score | 0.45 s | **0.44 s** (0.22 s with `OMP=1`) |
| peak RSS | 156 MB | **30 MB** |

Same anomaly ranking as scikit-learn (Spearman 0.96, equal AUC on the
breast-cancer benchmark in `bench/`).

## License

MIT — see LICENSE.
