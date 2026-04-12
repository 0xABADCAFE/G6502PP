# Configuration
BINARY_NAME=G65O2PP
TARGET_GO=build/processed.go
ENTRY_POINT=src/main.go
CC=gcc
GO=go

# Aggressive Optimization Flags
# -s: omit symbol table and debug info
# -w: omit DWARF generation
# -trimpath: remove local file system paths from the binary
GO_LDFLAGS=-ldflags="-s -w"
GO_GCFLAGS=-gcflags="all=-B -l"

.PHONY: all clean build

all: build

# 1 & 2. Preprocess and Compile
build: $(TARGET_GO)
	@echo "Compiling $(BINARY_NAME)..."
	@mkdir -p bin
	$(GO) build $(GO_LDFLAGS) $(GO_GCFLAGS) -trimpath -o bin/$(BINARY_NAME) $(TARGET_GO)

# The Preprocessing Step
# -P: Disable linemarker generation (crucial for Go)
# -xc: Treat input as C code
# -undef: Do not predefine any system-specific macros
$(TARGET_GO): $(ENTRY_POINT)
	@mkdir -p build
	@echo "Preprocessing Go files..."
	$(CC) -E -P -xc -undef $(ENTRY_POINT) -o $(TARGET_GO)
	@echo "Formatting intermediate file..."
	$(GO) fmt $(TARGET_GO)
clean:
	rm -rf build bin
