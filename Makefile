# Configuration
BINARY_NAME=G65O2PP
TARGET_GO=build/processed.go
ENTRY_POINT=src/main.go
GH_DEPS=$(wildcard src/*.gh)
CC=gcc
GO=go

# Aggressive Optimization Flags
# -s: omit symbol table and debug info
# -w: omit DWARF generation
# -trimpath: remove local file system paths from the binary
GO_LDFLAGS=-ldflags="-s -w"
GO_GCFLAGS=-gcflags="all=-B -l"

# goimports consolidates the split import blocks cpp emits; fall back to gofmt.
FMT := $(shell command -v goimports 2>/dev/null || echo gofmt)

# Prefer staticcheck; accept golangci-lint; degrade (with warning) if neither.
LINTER := $(shell command -v staticcheck 2>/dev/null || command -v golangci-lint 2>/dev/null)

VET_STAMP  := build/.vet.ok
LINT_STAMP := build/.lint.ok

.PHONY: all clean build fmt vet fix lint check
.SECONDARY: $(TARGET_GO) $(VET_STAMP) $(LINT_STAMP)

all: build

build: bin/$(BINARY_NAME)

# 1 & 2. Preprocess and Compile
bin/$(BINARY_NAME): $(TARGET_GO) $(VET_STAMP) $(LINT_STAMP)
	@echo "Compiling $(BINARY_NAME)..."
	@mkdir -p $(@D)
	$(GO) build $(GO_LDFLAGS) $(GO_GCFLAGS) -trimpath -o $@ $(TARGET_GO)

# The Preprocessing Step
# -P: Disable linemarker generation (crucial for Go)
# -xc: Treat input as C code
# -undef: Do not predefine any system-specific macros
$(TARGET_GO): $(ENTRY_POINT) $(GH_DEPS)
	@mkdir -p build
	@echo "Preprocessing Go files..."
	$(CC) -E -P -xc -undef $(ENTRY_POINT) -o $(TARGET_GO)
	@echo "Formatting intermediate file..."
	$(FMT) -w $(TARGET_GO)

$(VET_STAMP): $(TARGET_GO)
	@echo "  [vet] $<"
	@$(GO) vet $<
	@touch $@

$(LINT_STAMP): $(TARGET_GO)
	@if [ -n "$(LINTER)" ]; then \
	    echo "  [lint] $< ($(notdir $(LINTER)))"; \
	    case "$(notdir $(LINTER))" in \
	        staticcheck)     $(LINTER) $< ;; \
	        golangci-lint)   $(LINTER) run $< ;; \
	    esac; \
	else \
	    echo "  [lint] $< skipped (no staticcheck or golangci-lint in PATH)"; \
	fi
	@touch $@

# --- Phony convenience targets ----------------------------------------------

fmt: $(TARGET_GO)
	@echo "  [fmt] $<"; $(FMT) -w $<

vet: $(VET_STAMP)

lint: $(LINT_STAMP)

# `go fix` is advisory only: it prints suggestions that must be hand-applied
# back into the .gh / main.go sources, so it is never gated on the build.
fix: $(TARGET_GO)
	@echo "  [fix] $< (diff only — apply to .gh/main.go)"; $(GO) fix -diff $<

check: fmt vet lint fix

clean:
	rm -rf build bin/$(BINARY_NAME)
