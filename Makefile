FC     = gfortran
FFLAGS = -O2 -Wall -Jbuild
ifeq ($(OMP),1)
  FFLAGS += -fopenmp
endif

LIB = build/libiforest.a
BIN = build/iforest

all: $(BIN)

$(BIN): build/main.o $(LIB)
	$(FC) $(FFLAGS) $^ -o $@

$(LIB): build/iforest.o build/iforest_c.o
	ar rcs $@ $^

build/iforest.o: iforest.f90 | build
	$(FC) $(FFLAGS) -c $< -o $@

build/iforest_c.o: c_api.f90 build/iforest.o | build
	$(FC) $(FFLAGS) -c $< -o $@

build/main.o: main.f90 build/iforest.o | build
	$(FC) $(FFLAGS) -c $< -o $@

build:
	mkdir -p build

run: $(BIN)
	./$(BIN)

cdemo: $(LIB)
	gcc -c examples/example.c -Iinclude -o build/example.o
	$(FC) $(FFLAGS) build/example.o $(LIB) -o build/cdemo
	./build/cdemo

shared: | build
	$(FC) -O2 -fPIC -fopenmp -Jbuild -shared iforest.f90 c_api.f90 -o build/libiforest.so

# Static: C program + the .a, pulling the gfortran runtime.
cdemo-static: $(LIB)
	gcc examples/example.c -Iinclude build/libiforest.a -lgfortran -lm -o build/cdemo_static
	./build/cdemo_static

# Dynamic: link against the .so, found at runtime via LD_LIBRARY_PATH.
cdemo-dyn: shared
	gcc examples/example.c -Iinclude -Lbuild -liforest -o build/cdemo_dyn
	LD_LIBRARY_PATH=build ./build/cdemo_dyn

# Multiple forests scored concurrently (per-handle thread safety).
threads: $(LIB)
	gcc -c examples/threads.c -Iinclude -fopenmp -o build/threads.o
	$(FC) $(FFLAGS) -fopenmp build/threads.o $(LIB) -o build/threads
	./build/threads

cdemo-predict: $(LIB)
	gcc examples/predict.c -Iinclude build/libiforest.a -lgfortran -lm -o build/cdemo_predict
	./build/cdemo_predict

# Build and run every Fortran example.
examples: $(LIB)
	@for ex in basic predict multi params; do \
	  echo "--- examples/$$ex.f90 ---"; \
	  $(FC) $(FFLAGS) examples/$$ex.f90 $(LIB) -o build/$$ex && ./build/$$ex; \
	done

test: $(LIB)
	$(FC) $(FFLAGS) test/check.f90 $(LIB) -o build/check && ./build/check

stress: | build
	$(FC) -O0 -g -fcheck=all -fbacktrace -finit-real=snan -Jbuild iforest.f90 stress/stress.f90 -o build/stress && ./build/stress

check: test stress

clean:
	rm -rf build $(BIN)

.PHONY: all run cdemo shared cdemo-static cdemo-dyn cdemo-predict threads examples test stress check clean
