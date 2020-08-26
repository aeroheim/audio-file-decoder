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

First clone the repo, then navigate to the repo directory and run the following commands:
```bash
sudo apt-get update -qq
sudo apt-get install -y autoconf automake build-essential cmake git pkg-config wget

# grab emscripten sdk which is needed to compile ffmpeg
git clone https://github.com/emscripten-core/emsdk.git
./emsdk/emsdk install latest
./emsdk/emsdk activate latest

# TODO: can this command be invoked automatically by npm scripts instead?
# set emscripten environment variables
source ./emsdk/emsdk_env.sh

npm install && npm build-deps && npm build-wasm && npm build-js
```