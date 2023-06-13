# SPDX-License-Identifier: (GPL-2.0 OR BSD-2-Clause)

SRC_DIR = src
BUILD_DIR = build

XDP_C = $(wildcard $(SRC_DIR)/*.c)
XDP_OBJ = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(XDP_C))

USER_LIBS :=
EXTRA_DEPS :=

LLC ?= llc
CLANG ?= clang
CC ?= gcc

OBJECT_LIBBPF = /usr/lib/x86_64-linux-gnu/libbpf.a

LIBS = -l:libbpf.a -lelf $(USER_LIBS)

BPF_CFLAGS ?= -I/usr/include/bpf -I/usr/src/linux-headers-6.1.21-amd64-vyos/arch/x86/include/generated
BPF_CFLAGS += -Wall -Wno-unused-value -Wno-pointer-sign -Wno-compare-distinct-pointer-types
BPF_CFLAGS_EXTRA ?= -Werror -Wno-visibility
BPF_CFLAGS_USER ?=

ifeq ($(DEBUG), 1)
BPF_CFLAGS_USER += -DDEBUG
endif

all: llvm-check $(XDP_OBJ)

.PHONY: clean $(CLANG) $(LLC)

clean:
	rm -rf $(BUILD_DIR)
	rm -f *~

llvm-check: $(CLANG) $(LLC)
	@for TOOL in $^ ; do \
		if [ ! $$(command -v $${TOOL} 2>/dev/null) ]; then \
			echo "*** ERROR: Cannot find tool $${TOOL}" ;\
			exit 1; \
		else true; fi; \
	done

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJECT_LIBBPF):
	echo "Error: Need libbpf.a (apt-get install libbpf-dev"; \
	exit 1;

$(XDP_OBJ): $(BUILD_DIR)/%.o: $(SRC_DIR)/%.c  $(BUILD_DIR) $(OBJECT_LIBBPF) Makefile $(EXTRA_DEPS)
	$(CLANG) -S \
	    -target bpf \
	    -D __BPF_TRACING__ \
	    $(BPF_CFLAGS) $(BPF_CFLAGS_EXTRA) $(BPF_CFLAGS_USER) \
	    -O2 -emit-llvm -c -g -o ${@:.o=.ll} $<
	$(LLC) -march=bpf -filetype=obj -o $@ ${@:.o=.ll}
