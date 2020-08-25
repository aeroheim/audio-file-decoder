# tool macros
CC        := emcc
CCFLAG    := -Wall -O3 -fno-exceptions --no-entry -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s STRICT=1 -s MALLOC=emmalloc \
             -s MODULARIZE=1 -s EXPORT_ES6=1 -s EXTRA_EXPORTED_RUNTIME_METHODS=['FS'] --bind
DBGFLAG   := -g
LDFLAG    := `PKG_CONFIG_PATH="$$HOME/ffmpeg_build/lib/pkgconfig" pkg-config --cflags --libs libavcodec libavformat libavutil`
CCOBJFLAG := $(CCFLAG) -c

# path macros
DIST_PATH := dist
SRC_PATH  := src
OBJ_PATH  := obj
DEPS_PATH := deps

FFMPEG_SRC_PATH      := $(DEPS_PATH)/src/ffmpeg
FFMPEG_DIST_PATH     := $(DEPS_PATH)/dist/ffmpeg
LIBOPUS_SRC_PATH     := $(DEPS_PATH)/src/libopus
LIBOPUS_DIST_PATH    := $(DEPS_PATH)/dist/libopus
LIBMP3LAME_SRC_PATH  := $(DEPS_PATH)/src/libmp3lame
LIBMP3LAME_DIST_PATH := $(DEPS_PATH)/dist/libmp3lame


# compile macros
TARGET_NAME := decode-audio
TARGET := $(DIST_PATH)/$(TARGET_NAME).js

# src files & obj files
SRC := $(foreach x, $(SRC_PATH), $(wildcard $(addprefix $(x)/*,.c*)))
OBJ := $(addprefix $(OBJ_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))

# clean files list
CLEAN_LIST := $(OBJ_PATH) $(DIST_PATH)

# non-phony targets
$(TARGET): $(OBJ)
	@ mkdir -p $(DIST_PATH)
	$(CC) $(CCFLAG) -o $@ $? $(LDFLAG)

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c*
	@ mkdir -p $(OBJ_PATH)
	$(CC) $(CCOBJFLAG) -o $@ $< $(LDFLAG)

.PHONY: dist
# default rule
dist: $(TARGET)

sync: sync-ffmpeg sync-libopus

sync-ffmpeg:

sync-libopus:
	@ echo Syncing libopus from: https://github.com/xiph/opus.git
	@ mkdir -p $(LIBOPUS_SRC_PATH) && \
	git --git-dir=$(LIBOPUS_SRC_PATH)/.git pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git $(LIBOPUS_SRC_PATH)

sync-libmp3lame:
	@ echo Syncing libmp3lame from: https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
	@ mkdir -p $(LIBMP3LAME_SRC_PATH) && \
	wget -O $(LIBMP3LAME_SRC_PATH)/lame-3.100.tar.gz https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
	tar xzvf $(LIBMP3LAME_SRC_PATH)/lame-3.100.tar.gz --directory $(LIBMP3LAME_SRC_PATH)


unsync: unsync-ffmpeg unsync-libopus unsync-libmp3lame

unsync-ffmpeg:

unsync-libopus:
	@ echo Removing $(LIBOPUS_SRC_PATH)
	@ rm -rf $(LIBOPUS_SRC_PATH)

unsync-libmp3lame:


# sync-libmp3lame:

# make actual .so files target so make won't re-run redundantly
# build-deps: build-ffmpeg

# build-ffmpeg: build-libopus build-libmp3lame
#	@ mkdir -p $(DEPS_PATH)/src/ffmpeg

#build-libopus:

# build-libmp3lame:


clean-deps-libopus:
	@ rm -rf $(DEPS_PATH)/src/libopus

clean:
	@echo CLEAN $(CLEAN_LIST)
	@rm -rf $(CLEAN_LIST)