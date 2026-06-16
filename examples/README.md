# Examples

Build the library first: `make` from the repo root (and `make shared` for the
Julia example).

## Fortran

`make examples` builds and runs all three.

| file | shows |
|------|-------|
| `basic.f90`  | train a forest, score a batch |
| `multi.f90`  | two independent forests |
| `params.f90` | custom `n_trees` / `psi` |

By hand:

    gfortran -O2 -Jbuild examples/basic.f90 build/libiforest.a -o build/basic

## C

| file | target | shows |
|------|--------|-------|
| `example.c` | `make cdemo` / `cdemo-static` / `cdemo-dyn` | train / score, static + dynamic linking |
| `threads.c` | `make threads` | one forest per thread |

## Julia

    make shared
    julia examples/basic.jl         # uses wrappers/iforest.jl (ccall)
