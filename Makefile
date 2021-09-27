MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR  := $(dir $(MAKEFILE_PATH))

filter-false = $(strip $(filter-out 0 off OFF false FALSE,$1))
filter-true = $(strip $(filter-out 1 on ON true TRUE,$1))

# See contrib/local.mk.example
-include local.mk

all: nvim

CMAKE_PRG ?= $(shell (command -v cmake3 || echo cmake))
CMAKE_BUILD_TYPE ?= Debug
CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS ?=
NVIM_PRG := $(MAKEFILE_DIR)/build/bin/nvim

# CMAKE_INSTALL_PREFIX
#   - May be passed directly or as part of CMAKE_EXTRA_FLAGS.
#   - `checkprefix` target checks that it matches the CMake-cached value. #9615
ifneq (,$(CMAKE_INSTALL_PREFIX)$(CMAKE_EXTRA_FLAGS))
CMAKE_INSTALL_PREFIX := $(shell echo $(CMAKE_EXTRA_FLAGS) | 2>/dev/null \
    grep -o 'CMAKE_INSTALL_PREFIX=[^ ]\+' | cut -d '=' -f2)
endif
ifneq (,$(CMAKE_INSTALL_PREFIX))
override CMAKE_EXTRA_FLAGS += -DCMAKE_INSTALL_PREFIX=$(CMAKE_INSTALL_PREFIX)

checkprefix:
	@if [ -f build/.ran-cmake ]; then \
	  cached_prefix=$(shell $(CMAKE_PRG) -L -N build | 2>/dev/null grep 'CMAKE_INSTALL_PREFIX' | cut -d '=' -f2); \
	  if ! [ "$(CMAKE_INSTALL_PREFIX)" = "$$cached_prefix" ]; then \
	    printf "Re-running CMake: CMAKE_INSTALL_PREFIX '$(CMAKE_INSTALL_PREFIX)' does not match cached value '%s'.\n" "$$cached_prefix"; \
	    $(RM) build/.ran-cmake; \
	  fi \
	fi
else
checkprefix: ;
endif

CMAKE_GENERATOR ?= $(shell (command -v ninja > /dev/null 2>&1 && echo "Ninja") || \
    echo "Unix Makefiles")
DEPS_BUILD_DIR ?= .deps
ifneq (1,$(words [$(DEPS_BUILD_DIR)]))
  $(error DEPS_BUILD_DIR must not contain whitespace)
endif

ifeq (,$(BUILD_TOOL))
  ifeq (Ninja,$(CMAKE_GENERATOR))
    ifneq ($(shell $(CMAKE_PRG) --help 2>/dev/null | grep Ninja),)
      BUILD_TOOL = ninja
    else
      # User's version of CMake doesn't support Ninja
      BUILD_TOOL = $(MAKE)
      CMAKE_GENERATOR := Unix Makefiles
    endif
  else
    BUILD_TOOL = $(MAKE)
  endif
endif


# Only need to handle Ninja here.  Make will inherit the VERBOSE variable, and the -j, -l, and -n flags.
ifeq ($(CMAKE_GENERATOR),Ninja)
  ifneq ($(VERBOSE),)
    BUILD_TOOL += -v
  endif
  BUILD_TOOL += $(shell printf '%s' '$(MAKEFLAGS)' | grep -o -- ' *-[jl][0-9]\+ *')
  ifeq (n,$(findstring n,$(firstword -$(MAKEFLAGS))))
    BUILD_TOOL += -n
  endif
endif

DEPS_CMAKE_FLAGS ?=
# Back-compat: USE_BUNDLED_DEPS was the old name.
USE_BUNDLED ?= $(USE_BUNDLED_DEPS)

ifneq (,$(USE_BUNDLED))
  BUNDLED_CMAKE_FLAG := -DUSE_BUNDLED=$(USE_BUNDLED)
endif

ifneq (,$(findstring functionaltest-lua,$(MAKECMDGOALS)))
  BUNDLED_LUA_CMAKE_FLAG := -DUSE_BUNDLED_LUA=ON
  $(shell [ -x $(DEPS_BUILD_DIR)/usr/bin/lua ] || rm build/.ran-*)
endif

# For use where we want to make sure only a single job is run.  This does issue 
# a warning, but we need to keep SCRIPTS argument.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

nvim: build/.ran-cmake deps
	+$(BUILD_TOOL) -C build

libnvim: build/.ran-cmake deps
	+$(BUILD_TOOL) -C build libnvim

cmake:
	touch CMakeLists.txt
	$(MAKE) build/.ran-cmake

build/.ran-cmake: | deps
	cd build && $(CMAKE_PRG) -G '$(CMAKE_GENERATOR)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) $(MAKEFILE_DIR)
	touch $@

deps: | build/.ran-third-party-cmake
ifeq ($(call filter-true,$(USE_BUNDLED)),)
	+$(BUILD_TOOL) -C $(DEPS_BUILD_DIR)
endif

ifeq ($(call filter-true,$(USE_BUNDLED)),)
$(DEPS_BUILD_DIR):
	mkdir -p "$@"
build/.ran-third-party-cmake:: $(DEPS_BUILD_DIR)
	cd $(DEPS_BUILD_DIR) && \
		$(CMAKE_PRG) -G '$(CMAKE_GENERATOR)' $(BUNDLED_CMAKE_FLAG) $(BUNDLED_LUA_CMAKE_FLAG) \
		$(DEPS_CMAKE_FLAGS) $(MAKEFILE_DIR)/third-party
endif
build/.ran-third-party-cmake::
	mkdir -p build
	touch $@

# TODO: cmake 3.2+ add_custom_target() has a USES_TERMINAL flag.
oldtest: | nvim build/runtime/doc/tags
	+$(SINGLE_MAKE) -C src/nvim/testdir clean
ifeq ($(strip $(TEST_FILE)),)
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG=$(NVIM_PRG) $(MAKEOVERRIDES)
else
	@# Handle TEST_FILE=test_foo{,.res,.vim}.
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst %.vim,%,$(patsubst %.res,%,$(TEST_FILE)))
endif
# Build oldtest by specifying the relative .vim filename.
.PHONY: phony_force
src/nvim/testdir/%.vim: phony_force
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst src/nvim/testdir/%.vim,%,$@)

build/runtime/doc/tags helptags: | nvim
	+$(BUILD_TOOL) -C build runtime/doc/tags

# Builds help HTML _and_ checks for invalid help tags.
helphtml: | nvim build/runtime/doc/tags
	+$(BUILD_TOOL) -C build doc_html

functionaltest: | nvim
	+$(BUILD_TOOL) -C build functionaltest

functionaltest-lua: | nvim
	+$(BUILD_TOOL) -C build functionaltest-lua

stylua:
	stylua --check runtime/

lualint: | build/.ran-cmake deps
	$(BUILD_TOOL) -C build lualint

_opt_stylua:
	@command -v stylua && { $(MAKE) stylua; exit $$?; } \
		|| echo "SKIP: stylua (stylua not found)"

shlint:
	@shellcheck --version | head -n 2
	shellcheck scripts/vim-patch.sh

_opt_shlint:
	@command -v shellcheck && { $(MAKE) shlint; exit $$?; } \
		|| echo "SKIP: shlint (shellcheck not found)"

pylint:
	flake8 contrib/ scripts/ src/ test/

# Run pylint only if flake8 is installed.
_opt_pylint:
	@command -v flake8 && { $(MAKE) pylint; exit $$?; } \
		|| echo "SKIP: pylint (flake8 not found)"

commitlint:
	$(NVIM_PRG) -u NONE -es +"lua require('scripts.lintcommit').main({trace=false})"

_opt_commitlint:
	@test -x build/bin/nvim && { $(MAKE) commitlint; exit $$?; } \
		|| echo "SKIP: commitlint (build/bin/nvim not found)"

unittest: | nvim
	+$(BUILD_TOOL) -C build unittest

benchmark: | nvim
	+$(BUILD_TOOL) -C build benchmark

test: functionaltest unittest

clean:
	+test -d build && $(BUILD_TOOL) -C build clean || true
	$(MAKE) -C src/nvim/testdir clean
	$(MAKE) -C runtime/doc clean
	$(MAKE) -C runtime/indent clean

distclean:
	rm -rf $(DEPS_BUILD_DIR) build
	$(MAKE) clean

install: checkprefix nvim
	+$(BUILD_TOOL) -C build install

clint: build/.ran-cmake
	+$(BUILD_TOOL) -C build clint

clint-full: build/.ran-cmake
	+$(BUILD_TOOL) -C build clint-full

check-single-includes: build/.ran-cmake
	+$(BUILD_TOOL) -C build check-single-includes

generated-sources: build/.ran-cmake
	+$(BUILD_TOOL) -C build generated-sources

appimage:
	bash scripts/genappimage.sh

# Build an appimage with embedded update information.
#   appimage-nightly: for nightly builds
#   appimage-latest: for a release
appimage-%:
	bash scripts/genappimage.sh $*

lint: check-single-includes clint _opt_stylua lualint _opt_pylint _opt_shlint _opt_commitlint

style-lint: uncrustify

uncrustify-fix:
	bash scripts/run_uncrustify.sh -f

uncrustify:
	bash scripts/run_uncrustify.sh


# Generic pattern rules, allowing for `make build/bin/nvim` etc.
# Does not work with "Unix Makefiles".
ifeq ($(CMAKE_GENERATOR),Ninja)
build/%: phony_force
	$(BUILD_TOOL) -C build $(patsubst build/%,%,$@)

$(DEPS_BUILD_DIR)/%: phony_force
	$(BUILD_TOOL) -C $(DEPS_BUILD_DIR) $(patsubst $(DEPS_BUILD_DIR)/%,%,$@)
endif

.PHONY: test stylua lualint pylint shlint functionaltest unittest lint clint clean distclean nvim libnvim cmake deps install appimage checkprefix commitlint style-lint
