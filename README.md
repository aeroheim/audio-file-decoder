# ffmpeg-audio-decode-wasm
Tested only on Ubuntu. Use the official FFMPEG compilation [guide](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu) as reference.

## Compiling FFmpeg Dependencies
### libopus
The following script will pull the latest source libopus source and compile it with emscripten:
```bash
cd ~/ffmpeg_sources && \
git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git && \
cd opus && \
./autogen.sh && \
emconfigure ./configure \
  CFLAGS="-O3" \
  --prefix="$HOME/ffmpeg_build" \
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
```

### libmp3lame
The following script will fetch lame 3.100 and compile it with emscripten:
```bash
cd ~/ffmpeg_sources && \
wget -O lame-3.100.tar.gz https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
tar xzvf lame-3.100.tar.gz && \
cd lame-3.100 && \
PATH="$HOME/bin:$PATH" emconfigure ./configure \
  CFLAGS="-DNDEBUG -O3" \
  --prefix="$HOME/ffmpeg_build" \
  --bindir="$HOME/bin" \
  --host=x86-none-linux \
  --disable-shared \
  --disable-gtktest \
  --disable-analyzer-hooks \
  --disable-frontend \
  && \
PATH="$HOME/bin:$PATH" emmake make -j && \
emmake make install
```

```
  --disable-everything \
  --enable-decoder="aac*,mp*,msmp*,pcm*,flac,libopus,opus,vorbis" \
  --enable-demuxer="aac*,pcm*,mp3,ogg,flac,wav" \
```

## Compiling FFmpeg
```bash
cd ~/ffmpeg_sources/ffmpeg && \
PATH="$HOME/bin:$PATH" EM_PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" emconfigure ./configure \
  --cc=emcc \
  --ranlib=emranlib \
  --enable-cross-compile \
  --target-os=none \
  --arch=x86 \
  --disable-everything \
  --enable-decoder="aac*,mp*,msmp*,pcm*,flac,libopus,opus,vorbis" \
  --enable-demuxer="aac*,pcm*,mp3,ogg,flac,wav" \
  --enable-protocol="file" \
  --disable-programs \
  --disable-avdevice \
  --disable-swscale \
  --disable-postproc \
  --disable-avfilter \
  --disable-asm \
  --disable-runtime-cpudetect \
  --disable-fast-unaligned \
  --disable-pthreads \
  --disable-w32threads \
  --disable-os2threads \
  --disable-network \
  --disable-debug \
  --disable-stripping \
  --disable-safe-bitstream-reader \
  --disable-d3d11va \
  --disable-dxva2 \
  --disable-vaapi \
  --disable-vdpau \
  --disable-bzlib \
  --disable-iconv \
  --disable-libxcb \
  --disable-lzma \
  --disable-securetransport \
  --disable-xlib \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --bindir="$HOME/bin" \
  --enable-libopus \
  --enable-libmp3lame \
  && \
PATH="$HOME/bin:$PATH" emmake make -j && \
emmake make install && \
hash -r
```