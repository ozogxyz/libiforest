# Examples

Build the library first: `make` from the repo root (and `make shared` for the
Python and Julia examples).

## Fortran

`make examples` builds and runs all four.

| file | shows |
|------|-------|
| `basic.f90`   | train a forest, score a batch |
| `predict.f90` | binary labels by threshold and by contamination |
| `multi.f90`   | two independent forests |
| `params.f90`  | custom `n_trees` / `psi` |

By hand:

    gfortran -O2 -Jbuild examples/basic.f90 build/libiforest.a -o build/basic

## C

| file | target | shows |
|------|--------|-------|
| `example.c` | `make cdemo` / `cdemo-static` / `cdemo-dyn` | train / score / predict, static + dynamic linking |
| `predict.c` | `make cdemo-predict` | binary labels |
| `threads.c` | `make threads` | one forest per thread (per-handle thread safety) |

## Python

    make shared
    python examples/basic.py        # uses wrappers/iforest.py (ctypes)

## Julia

    make shared
    julia examples/basic.jl         # uses wrappers/iforest.jl (ccall)
