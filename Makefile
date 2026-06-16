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

test: $(LIB)
	$(FC) $(FFLAGS) test/check.f90 $(LIB) -o build/check && ./build/check

stress: | build
	$(FC) -O0 -g -fcheck=all -fbacktrace -finit-real=snan -Jbuild iforest.f90 stress/stress.f90 -o build/stress && ./build/stress

check: test stress

clean:
	rm -rf build $(BIN)

.PHONY: all run cdemo test stress check clean
