# Build targets:
#   bin/G65O2PP          — the NOP-block + Klaus-Dormann demo (src/main.go)
#   bin/G65O2PP_pinhot   — CLI bench harness (src/bench_main.go); A, SR, PC and
#                          the outside-memory pointer pinned to locals, X/Y/S
#                          stay as cpu-struct fields.
#   bin/G65O2PP_pinall   — same harness built with -DPIN_ALL so X, Y and S are
#                          also pinned. Empirically slower on current Go: the
#                          extra live locals exceed what the register allocator
#                          can keep hot across the dispatch switch.
#
# The bench binaries take `<bin_file> <instr_per_op> <seconds>` on the command
# line and print `<file>: ... [N MIPS] (M ops)`, so external harnesses can
# grep a single number out per run.
#
# Every build gates on `go vet` and (if installed) staticcheck/golangci-lint
# against the preprocessed build/<variant>/processed.go; any finding fails
# `make all`. Per-variant stamps keep the checks incremental.
#
# Fixes land in the .gh / *.go sources — build/*/processed.go is generated.

CC := gcc
GO := go

# -s/-w: strip symbol + DWARF info
# -B: disable bounds checks, -l: disable inlining budget limits
GO_LDFLAGS := -ldflags=-s -w
GO_GCFLAGS := -gcflags=all=-B -l

GH_DEPS := $(wildcard src/*.gh)

# Variants and their per-variant inputs / outputs.
VARIANTS := demo pinhot pinall

ENTRY_demo    := src/main.go
ENTRY_pinhot  := src/bench_main.go
ENTRY_pinall  := src/bench_main.go

CPPFLAGS_demo   :=
CPPFLAGS_pinhot :=
CPPFLAGS_pinall := -DPIN_ALL

BINNAME_demo   := G65O2PP
BINNAME_pinhot := G65O2PP_pinhot
BINNAME_pinall := G65O2PP_pinall

BINS       := $(foreach v,$(VARIANTS),bin/$(BINNAME_$(v)))
PROCESSED  := $(VARIANTS:%=build/%/processed.go)
VET_STAMPS := $(VARIANTS:%=build/%/.vet.ok)
LINT_STAMPS:= $(VARIANTS:%=build/%/.lint.ok)

# goimports consolidates the split import blocks cpp emits; fall back to gofmt.
FMT := $(shell command -v goimports 2>/dev/null || echo gofmt)

# Prefer staticcheck; accept golangci-lint; degrade (with warning) if neither.
LINTER := $(shell command -v staticcheck 2>/dev/null || command -v golangci-lint 2>/dev/null)

.PHONY: all clean $(VARIANTS) fmt vet fix lint check
.SECONDARY: $(PROCESSED) $(VET_STAMPS) $(LINT_STAMPS)

# Reverse map binary-name -> variant so the link rule below can look up the
# per-variant build dir from $*.
$(foreach v,$(VARIANTS),$(eval VARIANT_$(BINNAME_$(v)) := $(v)))

.SECONDEXPANSION:

all: $(BINS)

# Phony alias per variant so you can run e.g. `make pinhot`.
$(VARIANTS): %: bin/$$(BINNAME_$$*)

$(BINS): bin/%: build/$$(VARIANT_$$*)/processed.go build/$$(VARIANT_$$*)/.vet.ok build/$$(VARIANT_$$*)/.lint.ok
	@mkdir -p $(@D)
	$(GO) build "$(GO_LDFLAGS)" "$(GO_GCFLAGS)" -trimpath -o $@ $<

# -P: no linemarkers, -xc: C mode, -undef: no built-in system macros.
# $* is the variant name (demo/pinhot/pinall); ENTRY_$* picks the entry file.
build/%/processed.go: $$(ENTRY_$$*) $(GH_DEPS)
	@mkdir -p $(@D)
	$(CC) -E -P -xc -undef $(CPPFLAGS_$*) $(ENTRY_$*) -o $@
	$(FMT) -w $@

build/%/.vet.ok: build/%/processed.go
	@echo "  [vet] $<"
	@$(GO) vet $<
	@touch $@

build/%/.lint.ok: build/%/processed.go
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

fmt: $(PROCESSED)
	@for f in $^; do echo "  [fmt] $$f"; $(FMT) -w $$f; done

vet: $(VET_STAMPS)

lint: $(LINT_STAMPS)

# `go fix` is advisory only: suggestions must be hand-applied back to the
# .gh / *.go sources, so it is never gated on the build.
fix: $(PROCESSED)
	@for f in $^; do echo "  [fix] $$f (diff only — apply to .gh/*.go)"; $(GO) fix -diff $$f; done

check: fmt vet lint fix

clean:
	rm -rf build
	rm -f $(BINS)
