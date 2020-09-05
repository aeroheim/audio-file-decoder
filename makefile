# paths
LIB_PATH  := src/lib
SRC_PATH  := src/module
WASM_PATH := src/wasm
OBJ_PATH  := obj
DEPS_PATH := deps

# dependencies
EMSDK_VER              := 2.0.1
EMSDK_PATH             := $(DEPS_PATH)/emsdk
FFMPEG_VER             := 4.3.1
FFMPEG_SRC_PATH        := $(DEPS_PATH)/src/ffmpeg
FFMPEG_DIST_PATH       := $(DEPS_PATH)/dist/ffmpeg
FFMPEG_LIB_PATH        := $(FFMPEG_DIST_PATH)/lib
LIBOPUS_VER            := 1.3.1
LIBOPUS_SRC_PATH       := $(DEPS_PATH)/src/libopus
LIBOPUS_DIST_PATH      := $(DEPS_PATH)/dist/libopus
LIBMP3LAME_VER         := 3.100
LIBMP3LAME_SRC_PATH    := $(DEPS_PATH)/src/libmp3lame
LIBMP3LAME_DIST_PATH   := $(DEPS_PATH)/dist/libmp3lame

# targets
WASM_TARGET            := $(WASM_PATH)/decode-audio.js
WASM_WORKER_TARGET     := $(WASM_PATH)/decode-audio-worker.js
WASM_WORKER_SRC        := $(LIB_PATH)/worker.js
FFMPEG_TARGET_NAME     := libavcodec libavformat libavutil
FFMPEG_TARGET          := $(foreach target, $(FFMPEG_TARGET_NAME), $(FFMPEG_LIB_PATH)/$(target).a)
LIBOPUS_TARGET_NAME    := libopus
LIBOPUS_TARGET         := $(foreach target, $(LIBOPUS_TARGET_NAME), $(FFMPEG_LIB_PATH)/$(target).a)
LIBMP3LAME_TARGET_NAME := libmp3lame
LIBMP3LAME_TARGET      := $(foreach target, $(LIBMP3LAME_TARGET_NAME), $(FFMPEG_LIB_PATH)/$(target).a)

# compiler flags
CC            := emcc
COMMON_CCFLAG := \
	-Wall \
	-O3 \
	--closure 1 \
	--no-entry \
	-fno-exceptions \
	-s WASM=1 \
	-s STRICT=1 \
	-s MODULARIZE=1 \
	-s MALLOC=emmalloc \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s EXTRA_EXPORTED_RUNTIME_METHODS=['FS'] \
	--bind
CCFLAG        := \
	$(COMMON_CCFLAG) \
	-s EXPORT_ES6
CCFLAG_WORKER := \
	$(COMMON_CCFLAG) \
	-s --extern-post-js $(WASM_WORKER_SRC)
CCOBJFLAG     := $(COMMON_CCFLAG) -c
LDFLAG        := `PKG_CONFIG_PATH="$(FFMPEG_LIB_PATH)/pkgconfig" pkg-config --cflags --libs $(FFMPEG_TARGET_NAME)`

# src files & obj files
SRC := $(foreach x, $(SRC_PATH), $(wildcard $(addprefix $(x)/*,.c*)))
OBJ := $(addprefix $(OBJ_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))

# the default target
wasm: $(WASM_TARGET) $(WASM_WORKER_TARGET)

# wasm file & js file with glue code to be included in library bundle
$(WASM_TARGET): $(OBJ)
	@ mkdir -p $(WASM_PATH)
	$(CC) $(CCFLAG) -o $@ $? $(LDFLAG)

# worker js file with glue code inlined
$(WASM_WORKER_TARGET): $(OBJ)
	@ mkdir -p $(WASM_PATH)
	EMCC_CLOSURE_ARGS="--language_in=ECMASCRIPT6" $(CC) $(CCFLAG_WORKER) -o $@ $? $(LDFLAG)

# object files
$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c*
	@ mkdir -p $(OBJ_PATH)
	$(CC) $(CCOBJFLAG) -o $@ $< $(LDFLAG)

# phony targets
.PHONY: clean \
	deps ffmpeg libopus libmp3lame \
	clean-deps clean-ffmpeg clean-libopus clean-libmp3lame \
	sync sync-ffmpeg sync-libopus sync-libmp3lame \
	unsync unsync-ffmpeg unsync-libopus unsync-libmp3lame

clean:
	@echo Removing $(OBJ_PATH) $(WASM_PATH)
	@rm -rf $(OBJ_PATH) $(WASM_PATH)

# rules for dependencies
deps: ffmpeg libopus libmp3lame

ffmpeg: $(FFMPEG_TARGET) $(LIBOPUS_TARGET) $(LIBMP3LAME_TARGET)
$(FFMPEG_TARGET) &:
	@ echo Compiling FFmpeg $(FFMPEG_VER)
	@ cd $(FFMPEG_SRC_PATH) && \
	EM_PKG_CONFIG_PATH="../../../$(FFMPEG_DIST_PATH)/lib/pkgconfig" emconfigure ./configure \
	--cc=emcc --ranlib=emranlib --target-os=none --arch=x86 \
	--disable-everything --disable-all \
	--enable-avcodec --enable-avformat --enable-avutil \
	--enable-decoder="aac*,mp3*,pcm*,flac,libopus,opus,vorbis" \
	--enable-demuxer="aac*,mov,pcm*,mp3,ogg,flac,wav" \
	--enable-libopus \
	--enable-libmp3lame \
	--enable-protocol="file" \
	--disable-programs  \
	--disable-asm --disable-runtime-cpudetect --disable-fast-unaligned --disable-pthreads --disable-w32threads --disable-os2threads \
	--disable-network --disable-debug --disable-stripping --disable-safe-bitstream-reader \
	--disable-d3d11va --disable-dxva2 --disable-vaapi --disable-vdpau --disable-bzlib \
	--disable-iconv --disable-libxcb --disable-lzma --disable-securetransport --disable-xlib \
	--pkg-config-flags="--static" \
	--prefix=$$(pwd)/../../../$(FFMPEG_DIST_PATH) \
	--extra-cflags="-I../../../$(FFMPEG_DIST_PATH)/include" \
	--extra-ldflags="-L../../../$(FFMPEG_DIST_PATH)/lib" \
	&& \
	emmake make -j && \
	emmake make install

libopus: $(LIBOPUS_TARGET)
$(LIBOPUS_TARGET) &:
	@ echo Compiling libopus $(LIBOPUS_VER)
	@ mkdir -p $(FFMPEG_DIST_PATH) && cd $(LIBOPUS_SRC_PATH) && \
	./autogen.sh && \
	emconfigure ./configure \
	CFLAGS="-O3" \
	--prefix=$$(pwd)/../../../$(FFMPEG_DIST_PATH) \
	--disable-shared \
	--disable-rtcd \
	--disable-asm \
	--disable-intrinsics \
	--disable-doc \
	--disable-extra-programs \
	--disable-hardening \
	--disable-stack-protector \
	&& \
	emmake make -j && \
	emmake make install

libmp3lame: $(LIBMP3LAME_TARGET)
$(LIBMP3LAME_TARGET) &:
	@ echo Compiling libmp3lame $(LIBMP3LAME_VER)
	@ mkdir -p $(FFMPEG_DIST_PATH) && cd $(LIBMP3LAME_SRC_PATH) && \
	emconfigure ./configure \
	CFLAGS="-DNDEBUG -O3" \
	--prefix=$$(pwd)/../../../$(FFMPEG_DIST_PATH) \
	--disable-shared \
	--disable-gtktest \
	--disable-analyzer-hooks \
	--disable-frontend \
	--host=x86-none-linux \
	&& \
	emmake make -j && \
	emmake make install

# rules for cleaning dependencies
clean-deps: clean-ffmpeg clean-libopus clean-libmp3lame
clean-ffmpeg:
	@ cd $(FFMPEG_SRC_PATH) && \
	emmake make clean || true && \
	emmake make uninstall || true && \
	echo Done!

clean-libopus:
	@ cd $(LIBOPUS_SRC_PATH) && \
	emmake make clean || true && \
	emmake make uninstall || true && \
	echo Done!

clean-libmp3lame:
	@ cd $(LIBMP3LAME_SRC_PATH) && \
	emmake make clean || true && \
	emmake make uninstall || true && \
	echo Done!

# rules for syncing/downloading dependencies
sync: sync-ffmpeg sync-libopus sync-libmp3lame
sync-ffmpeg:
	@ echo Syncing FFmpeg $(FFMPEG_VER) from: https://ffmpeg.org/releases/ffmpeg-$(FFMPEG_VER).tar.bz2
	@ mkdir -p $(FFMPEG_SRC_PATH) && \
	wget -nc -O $(FFMPEG_SRC_PATH)/ffmpeg-$(FFMPEG_VER).tar.bz2 https://ffmpeg.org/releases/ffmpeg-$(FFMPEG_VER).tar.bz2 || true && \
	echo Extracting FFmpeg.. && \
	tar xjf $(FFMPEG_SRC_PATH)/ffmpeg-$(FFMPEG_VER).tar.bz2 --directory $(FFMPEG_SRC_PATH) --strip-components 1 && \
	echo Done!

sync-libopus:
	@ echo Syncing libopus $(LIBOPUS_VER) from: https://github.com/xiph/opus.git
	@ mkdir -p $(LIBOPUS_SRC_PATH) && \
	git --git-dir=$(LIBOPUS_SRC_PATH)/.git pull 2> /dev/null || \
	git clone --depth 1 --branch v$(LIBOPUS_VER) https://github.com/xiph/opus.git $(LIBOPUS_SRC_PATH) && \
	echo Done!

sync-libmp3lame:
	@ echo Syncing libmp3lame $(LIBMP3LAME_VER) from: https://downloads.sourceforge.net/project/lame/lame/$(LIBMP3LAME_VER)/lame-$(LIBMP3LAME_VER).tar.gz
	@ mkdir -p $(LIBMP3LAME_SRC_PATH) && \
	wget -nc -O $(LIBMP3LAME_SRC_PATH)/lame-$(LIBMP3LAME_VER).tar.gz https://downloads.sourceforge.net/project/lame/lame/$(LIBMP3LAME_VER)/lame-$(LIBMP3LAME_VER).tar.gz || true && \
	echo Extracting libmp3lame.. && \
	tar xzf $(LIBMP3LAME_SRC_PATH)/lame-$(LIBMP3LAME_VER).tar.gz --directory $(LIBMP3LAME_SRC_PATH) --strip-components 1 && \
	echo Done!

# rules for unsycing/removing dependencies
unsync: unsync-ffmpeg unsync-libopus unsync-libmp3lame
unsync-ffmpeg:
	@ echo Removing $(FFMPEG_SRC_PATH)
	@ rm -rf $(FFMPEG_SRC_PATH) && \
	echo Done!

unsync-libopus:
	@ echo Removing $(LIBOPUS_SRC_PATH)
	@ rm -rf $(LIBOPUS_SRC_PATH) && \
	echo Done!

unsync-libmp3lame:
	@ echo Removing $(LIBMP3LAME_SRC_PATH)
	@ rm -rf $(LIBMP3LAME_SRC_PATH) && \
	echo Done!
