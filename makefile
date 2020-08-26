# path macros
DIST_PATH := dist
SRC_PATH  := src/cpp
OBJ_PATH  := obj
DEPS_PATH := deps

EMSDK_VER            := 2.0.1
EMSDK_PATH           := $(DEPS_PATH)/emsdk
FFMPEG_VER           := 4.3.1
FFMPEG_SRC_PATH      := $(DEPS_PATH)/src/ffmpeg
FFMPEG_DIST_PATH     := $(DEPS_PATH)/dist/ffmpeg
LIBOPUS_VER          := 1.3.1
LIBOPUS_SRC_PATH     := $(DEPS_PATH)/src/libopus
LIBOPUS_DIST_PATH    := $(DEPS_PATH)/dist/libopus
LIBMP3LAME_VER       := 3.100
LIBMP3LAME_SRC_PATH  := $(DEPS_PATH)/src/libmp3lame
LIBMP3LAME_DIST_PATH := $(DEPS_PATH)/dist/libmp3lame

# compiler macros
CC        := emcc
CCFLAG    := -Wall -O3 -fno-exceptions --no-entry -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s STRICT=1 -s MALLOC=emmalloc \
			 -s MODULARIZE=1 -s EXPORT_ES6=1 -s EXTRA_EXPORTED_RUNTIME_METHODS=['FS'] --bind
LDFLAG    := `PKG_CONFIG_PATH="$(FFMPEG_DIST_PATH)/lib/pkgconfig" pkg-config --cflags --libs libavcodec libavformat libavutil`
CCOBJFLAG := $(CCFLAG) -c

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

# phony targets
.PHONY: dist \
	clean \
	deps ffmpeg libopus libmp3lame \
	clean-deps clean-ffmpeg clean-libopus clean-libmp3lame \
	sync sync-ffmpeg sync-libopus sync-libmp3lame \
	unsync unsync-ffmpeg unsync-libopus unsync-libmp3lame

# default rule
dist: $(TARGET)

clean:
	@echo CLEAN $(CLEAN_LIST)
	@rm -rf $(CLEAN_LIST)

# make actual .so files target so make won't re-run redundantly
deps: ffmpeg libopus libmp3lame
ffmpeg:
	@ echo Compiling FFmpeg $(FFMPEG_VER)
	@ cd $(FFMPEG_SRC_PATH) && \
	EM_PKG_CONFIG_PATH=../../../$(FFMPEG_DIST_PATH)/lib/pkgconfig emconfigure ./configure \
	--cc=emcc --ranlib=emranlib --target-os=none --arch=x86 --disable-everything \
	--enable-decoder="aac*,mp*,msmp*,pcm*,flac,libopus,opus,vorbis" \
	--enable-demuxer="aac*,pcm*,mp3,ogg,flac,wav" \
	--enable-libopus \
	--enable-libmp3lame \
	--enable-protocol="file" \
	--disable-programs --disable-avdevice --disable-swscale --disable-postproc --disable-avfilter \
	--disable-asm --disable-runtime-cpudetect --disable-fast-unaligned --disable-pthreads --disable-w32threads --disable-os2threads \
	--disable-network --disable-debug --disable-stripping --disable-safe-bitstream-reader \
	--disable-d3d11va --disable-dxva2 --disable-vaapi --disable-vdpau --disable-bzlib \
	--disable-iconv --disable-libxcb --disable-lzma --disable-securetransport --disable-xlib \
	--pkg-config-flags="--static" \
	--prefix=$$(pwd)/../../../$(FFMPEG_DIST_PATH) \
	--extra-cflags="-I../../../$(FFMPEG_DIST_PATH)/include" \
	--extra-ldflags="-L../../../$(FFMPEG_DIST_PATH)/lib" \
	--bindir="$$HOME/bin" \
	&& \
	emmake make -j && \
	emmake make install

libopus:
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

libmp3lame:
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

clean-deps: clean-ffmpeg clean-libopus clean-libmp3lame
clean-ffmpeg:
	@ cd $(FFMPEG_SRC_PATH) && \
	emmake make clean && \
	emmake make uninstall && \
	echo Done!

clean-libopus:
	@ cd $(LIBOPUS_SRC_PATH) && \
	emmake make clean && \
	emmake make uninstall && \
	echo Done!

clean-libmp3lame:
	@ cd $(LIBMP3LAME_SRC_PATH) && \
	emmake make clean && \
	emmake make uninstall && \
	echo Done!

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
