# tool macros
CC        := emcc
CCFLAG    := -Wall -O3 --no-entry -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s STRICT=1 -s MALLOC=emmalloc \
             -s MODULARIZE=1 -s EXPORT_ES6=1 -s FORCE_FILESYSTEM=1 -s EXTRA_EXPORTED_RUNTIME_METHODS=['FS'] --bind
DBGFLAG   := -g
LDFLAG    := `PKG_CONFIG_PATH="$$HOME/ffmpeg_build/lib/pkgconfig" pkg-config --cflags --libs libavcodec libavformat libswresample libavutil`
CCOBJFLAG := $(CCFLAG) -c

# path macros
DIST_PATH := dist
OBJ_PATH := obj
SRC_PATH := src

# compile macros
TARGET_NAME := decode-audio
TARGET := $(DIST_PATH)/$(TARGET_NAME).js

# src files & obj files
SRC := $(foreach x, $(SRC_PATH), $(wildcard $(addprefix $(x)/*,.c*)))
OBJ := $(addprefix $(OBJ_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))

# clean files list
CLEAN_LIST := $(OBJ_PATH) $(DIST_PATH)

# default rule
default: all

# non-phony targets
$(TARGET): $(OBJ)
	@ mkdir -p $(DIST_PATH)
	$(CC) $(CCFLAG) -o $@ $? $(LDFLAG)

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c*
	@ mkdir -p $(OBJ_PATH)
	$(CC) $(CCOBJFLAG) -o $@ $< $(LDFLAG)

# phony rules
.PHONY: all
all: $(TARGET)

.PHONY: clean
clean:
	@echo CLEAN $(CLEAN_LIST)
	@rm -rf $(CLEAN_LIST)