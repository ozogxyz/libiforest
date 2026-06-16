# libiforest

Isolation Forest anomaly detection as a small, dependency-free Fortran library —
one file (`iforest.f90`), builds to `libiforest.a`, callable from Fortran, C, and
Julia. Faster and far leaner than scikit-learn's `IsolationForest`, with no Python
or BLAS in the loop, so it drops straight into existing Fortran / HPC / native
data pipelines.

Build it once:

    make            # -> build/libiforest.a  (and build/iforest demo)
    make shared     # -> build/libiforest.so (needed for Julia)

Then: train a forest on `X` (rows = samples, columns = features), score each row.
A score is in `(0, 1]` — about `0.5` for ordinary points, toward `1` for
anomalies. For labels, threshold it yourself (`score >= t`).

## Fortran

Save as `demo.f90`:

```fortran
program demo
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: forest
  real(dp) :: X(101, 2), s(101), a, b
  integer :: i

  do i = 1, 100                          ! 100 inliers in the unit square
     call random_number(a); call random_number(b)
     X(i,:) = [a, b]
  end do
  X(101,:) = [5.0_dp, 5.0_dp]            ! 1 outlier

  call train_forest(forest, X, 101)      ! 100 trees, psi = min(256, n)
  call predict_scores(forest, X, 101, s)
  print '(a,f5.3,a,f5.3)', "inlier ", s(1), "   outlier ", s(101)

  call free_forest(forest)
end program demo
```

    gfortran -O2 -Jbuild demo.f90 build/libiforest.a -o demo && ./demo
    # inlier 0.46x   outlier 0.90x

## C

Save as `demo.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include "iforest.h"

int main(void)
{
    int n = 101, m = 2, i;
    double *X = malloc(sizeof(double) * n * m);

    for (i = 0; i < 100; i++) {            /* 100 inliers */
        X[i * m + 0] = (double)rand() / RAND_MAX;
        X[i * m + 1] = (double)rand() / RAND_MAX;
    }
    X[100 * m + 0] = 5.0;                   /* 1 outlier */
    X[100 * m + 1] = 5.0;

    iforest_t f = iforest_train(X, n, m, 100, 0);   /* psi = 0 -> auto */
    double *s = malloc(sizeof(double) * n);
    iforest_score(f, X, n, m, s);
    printf("inlier %.3f   outlier %.3f\n", s[0], s[100]);

    iforest_free(f);
    free(X);
    free(s);
    return 0;
}
```

    gcc demo.c -Iinclude build/libiforest.a -lgfortran -lm -o demo && ./demo
    # static link; for the shared lib: gcc demo.c -Iinclude -Lbuild -liforest && LD_LIBRARY_PATH=build ./a.out

## Julia

Save as `demo.jl` (needs `make shared`):

```julia
include("wrappers/iforest.jl")
using .IForest

X = vcat(rand(100, 2), [5.0 5.0])          # 100 inliers + 1 outlier
f = IForest.fit(X)                         # n_trees = 100, psi = auto
s = IForest.score(f, X)
println("inlier ", round(s[1], digits=3), "   outlier ", round(s[end], digits=3))
```

    julia demo.jl

## Build targets

    make            # libiforest.a + the demo
    make examples   # build and run the Fortran examples in examples/
    make test       # quick sanity test
    make stress     # stress suite (runtime-checked)
    make shared     # libiforest.so
    make OMP=1      # parallel training and scoring (OpenMP)
    make clean

Each forest is independent — one per thread is safe (see `examples/threads.c`).
Full call reference in [docs/API.md](docs/API.md).

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
