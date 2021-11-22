
BUILD_PATH     = ./build
BUILD_FLAGS    = -std=c11 -Wall -g -O0
CFLAGS         = -framework Cocoa -framework Carbon -framework CoreServices \
		-shared -undefined dynamic_lookup
SKHD_SRC       = $(wildcard *.c)
# /opt/homebrew/Cellar/nim/1.4.8/nim/lib/nimbase.h ~/.cache/nim/main_d/nim.h
# NIM            = -L../ -lckhd
# ~/.cache/nim/main_d/*.c
BIN            = $(BUILD_PATH)/libckhd.so

.PHONY: all clean install

all: $(BIN)

install: BUILD_FLAGS=-std=c99 -Wall -O2
install: clean $(BIN)

clean:
	rm -rf $(BUILD_PATH)/*

# parser: src/myparser.c
# 	mkdir -p $(BUILD_PATH)
# 	arch -arm64 clang $^ $(BUILD_FLAGS) $(CFLAGS) -o $(BUILD_PATH)/$@

$(BIN): $(SKHD_SRC)
	mkdir -p $(BUILD_PATH)
	arch -arm64 clang $^ $(NIM) $(CFLAGS) $(BUILD_FLAGS) -o $@