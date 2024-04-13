# ---------------------------------------------------------------------
# OS parsing

ifeq ($(OS),Windows_NT)
	OSFLAGS = -shared -fPIC -lgfortran
	GCC = x86_64-w64-mingw32-gcc.exe
	GFORTRAN = x86_64-w64-mingw32-gfortran.exe
	MVNORM_OUT = src/build/pretrends_mvnorm_windows.plugin
	F77FLAGS = -fPIC -O3
	ARCH =
else
	UNAME_S := $(shell uname -s)
	UNAME_M := $(shell uname -m)
	ifeq ($(UNAME_S),Linux)
		GCC = gcc
		GFORTRAN = gfortran
		OSFLAGS = -shared -fPIC -DSYSTEM=OPUNIX -lgfortran
		F77FLAGS = -fPIC -DSYSTEM=OPUNIX -O3
		MVNORM_OUT = src/build/pretrends_mvnorm_unix.plugin
		ARCH =
	endif
	ifeq ($(UNAME_S),Darwin)
		GCC = clang
		GFORTRAN = gfortran
		OSFLAGS = -bundle -DSYSTEM=APPLEMAC -lgfortran
		F77FLAGS = -bundle -O3
		ifeq ($(UNAME_M),x86_64)
			ARCH = -arch x86_64
			MVNORM_OUT = src/build/pretrends_mvnorm_macosx86_64.plugin
		endif
		ifeq ($(UNAME_M),arm64)
			ARCH = -arch arm64
			MVNORM_OUT = src/build/pretrends_mvnorm_macosxarm64.plugin
		endif
	endif
endif

ifeq ($(EXECUTION),windows)
	OSFLAGS = -shared -lgfortran
	F77FLAGS =
	ARCH =
	GCC = x86_64-w64-mingw32-gcc
	GFORTRAN = x86_64-w64-mingw32-gfortran
	MVNORM_OUT = src/build/pretrends_mvnorm_windows.plugin
endif

CFLAGS = -Wall -O3 $(OSFLAGS)

# ---------------------------------------------------------------------
# Main

## Compile directory
all: clean mvnorm

# ---------------------------------------------------------------------
# Rules

## Compile mvnorm plugin
src/plugin/mvtdstpack.o: src/plugin/mvtdstpack.f
	$(GFORTRAN) -c $^ -o $@ $(F77FLAGS) $(ARCH) -std=legacy

mvnorm: src/plugin/mvtdstpack.o src/plugin/pretrends_mvnorm.c src/plugin/stplugin.c
	$(GCC) $(CFLAGS) -o $(MVNORM_OUT) $(ARCH) $^

.PHONY: clean
clean:
	rm -f $(MVNORM_OUT) src/plugin/mvtdstpack.o

#######################################################################
#                                                                     #
#                    Self-Documenting Foo (Ignore)                    #
#                                                                     #
#######################################################################

.DEFAULT_GOAL := show-help

.PHONY: show-help
show-help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')

