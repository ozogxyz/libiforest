FC     = gfortran
FFLAGS = -O2 -Wall -Jbuild

LIB = build/libiforest.a
BIN = build/iforest

all: $(BIN)

$(BIN): build/main.o $(LIB)
	$(FC) $(FFLAGS) $^ -o $@

$(LIB): build/iforest.o
	ar rcs $@ $^

build/iforest.o: iforest.f90 | build
	$(FC) $(FFLAGS) -c $< -o $@

build/main.o: main.f90 build/iforest.o | build
	$(FC) $(FFLAGS) -c $< -o $@

build:
	mkdir -p build

run: $(BIN)
	./$(BIN)

test: $(LIB)
	$(FC) $(FFLAGS) test/check.f90 $(LIB) -o build/check && ./build/check

clean:
	rm -rf build $(BIN)

.PHONY: all run test clean
