# audio-file-decoder
## About
A library for decoding audio files, including specific timestamp ranges within files. Written with FFmpeg and WebAssembly and can be used in both browser and node environments.

Supported audio file formats include:
* MP3
* WAV
* FLAC
* AAC (investigate why this isn't working)
* OGG

### Why?
[WebAudio](https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/decodeAudioData) currently provides `decodeAudioData` as a means to access raw samples from audio files in a non-realtime manner. It only supports decoding entire audio files however which is a surprising oversight since uncompressed audio samples can take *huge* amounts of memory. For example, a 10 minute long audio file assuming a typical sample rate of 44100 Hz, floating point samples, and stereo channels will occupy 44100 Hz * 600 seconds * 4 bytes * 2 channels = ~212 MB of memory.

There are several client-side use cases such as waveform generation, DSP, MIR, etc. where loading entire uncompressed audio files is overkill and streaming small chunks of decoded samples is preferred. In the future the [WebCodecs](https://github.com/WICG/web-codecs) proposal may address this oversight but until then this can be considered an alternative to WebAudio's `decodeAudioData`.

### Caveats
* This library has to keep files in memory in browser environments since the filesystem is sandboxed. For node environments this isn't an issue as the native filesystem is accessible.
* Performance is about ~2x slower than chromium's implementation of `decodeAudioData`. Chromium's implementation also uses FFmpeg for decoding, but is able to run natively with threading and native optimizations enabled, while this library has them disabled for WebAssembly compatibility.
* This library does **NOT** resample decoded audio, whereas `decodeAudioData` will automatically resample to the sample rate of its `AudioContext`.
* Sample position accuracy may be slightly off when decoding timestamp ranges due to timestamp precision and how FFmpeg's seek behaves. FFmpeg tries to seek to the closest frame possible for timestamps which may introduce an error of a few frames, where each frame contains a fixed (e.g 1024 samples) or dynamic number of samples depending on the audio file encoding.

## Usage
TODO  

## License
probably LGPL

## Building
The build steps below have been tested on Ubuntu 20.04.1 LTS.

```bash
sudo apt-get update -qq
sudo apt-get install -y autoconf automake build-essential cmake git pkg-config wget

npm install-deps && npm install
```

### FFmpeg
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