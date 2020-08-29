# audio-file-decoder
[![npm version](https://img.shields.io/npm/v/audio-file-decoder.svg)](https://npmjs.org/package/audio-file-decoder "View this project on npm")

## About
A library for decoding audio files in browser and node environments, including specific timestamp ranges within files. Written with FFmpeg and WebAssembly and supports the following audio file formats:
* MP3
* WAV
* FLAC
* AAC/M4A
* OGG

### Why?
[WebAudio](https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/decodeAudioData) currently provides `decodeAudioData` as a means to access raw samples from audio files in a faster than realtime manner. It only supports decoding entire audio files however which can take *huge* amounts of memory. For example, a 10 minute audio file with a sample rate of 44100 Hz, floating point samples, and stereo channels will occupy 44100 Hz * 600 seconds * 4 bytes * 2 channels = ~212 MB of memory when uncompressed.

The [WebCodecs](https://github.com/WICG/web-codecs) proposal is planning to address this oversight (see [here](https://github.com/WICG/web-codecs/issues/28) for more info) but until adoption by browsers this can be used as a more memory-friendly alternative to WebAudio's current implementation.

### Notes
* Files still need be stored in memory for access since the filesystem is sandboxed. The advantage of using this library is that uncompressed data no longer needs to be fully stored in memory.
* Multiple channels are automatically downmixed into a single channel via sample averaging.
* Decoded audio is **NOT** resampled, whereas `decodeAudioData` will automatically resample to the sample rate of its `AudioContext`.
* Sample position accuracy may be slightly off when decoding timestamp ranges due to timestamp precision and how FFmpeg's seek behaves. FFmpeg tries to seek to the closest frame possible for timestamps which may introduce an error of a few frames, where each frame contains a fixed (e.g 1024 samples) or dynamic number of samples depending on the audio file encoding.
* Performance is about ~2x slower than Chromium's implementation of `decodeAudioData`. Chromium's implementation also uses FFmpeg for decoding, but is able to run natively with threading and native optimizations enabled, while this library has them disabled for WebAssembly compatibility.

## Usage
An example usage of the decoder in ES6:
```js
import { getAudioDecoder } from 'audio-file-decoder';

getAudioDecoder(file)
  .then(decoder => {
    const sampleRate = decoder.sampleRate; // the sample rate of the audio file (e.g 44100)
    const channelCount = decoder.channelCount; // the number of channels in the audio file (e.g 2 if stereo)
    const encoding = decoder.encoding; // the encoding of the audio file as a string (e.g pcm_s16le)

    let samples;

    // decode entire audio file
    samples = decoder.decodeAudioData();

    // decode from 5.5 seconds to the end of the file
    samples = decoder.decodeAudioData(5.5, -1);

    // decode from 30 seconds to 90 seconds
    samples = decoder.decodeAudioData(30, 60);

    // make sure to dispose once finished to free resources
    decoder.dispose();
  });
```

You'll need to include the wasm file provided by this library as a static asset in your application as well. The wasm file is located at:
```bash
/node_modules/audio-file-decoder/dist/decode-audio.wasm
```

For example, a typical application using this library should include it as an asset like in the example file structure below:
```bash
app/
  dist/
    index.html
    index.js
    decode-audio.wasm
```

The wasm file can be copied in whatever manner is convenient (e.g a build script, or plugins for copying static assets if using bundlers such as Webpack or Rollup). Make sure to preserve the asset name when copying, otherwise the wasm module will fail to load.

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

# set emscripten environment variables
source ./emsdk/emsdk_env.sh

# install npm deps, sync/download ffmpeg + deps, then build ffmpeg
# will only need to be run once unless you plan on making changes to how ffmpeg/dependencies are compiled
npm install && npm run sync && npm run build-deps

# build the wasm module and the library
# basic workflow when making changes to the wasm module/js library
npm run build-wasm && npm run build
```

Commands for the WebAssembly module, which can be useful if modifying or extending the C++ wrapper around FFmpeg:
```bash
# build the WebAssembly module - output is located at src/wasm
npm run build-wasm

# removes the wasm output
npm run clean-wasm
```

Commands for FFmpeg and dependencies, which can be useful if modifying the compilation of FFmpeg and its dependencies:
```bash
# downloads FFmpeg and its dependencies - output is located at deps/src
npm run sync

# removes FFmpeg and its dependencies 
npm run unsync

# builds FFmpeg and its dependencies - output is located at deps/dist/ffmpeg
npm run build-deps

# cleans the FFmpeg dist output
npm run clean-deps
```

## License
Licensed under LGPL v2.1 or later. See the [license file](./LICENSE) for more info.