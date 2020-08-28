# audio-file-decoder
## About
A library for decoding audio files in browser and node environments, including specific timestamp ranges within files. Written with FFmpeg and WebAssembly and supports the following audio file formats:
* MP3
* WAV
* FLAC
* AAC/M4A
* OGG

### Why?
[WebAudio](https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/decodeAudioData) currently provides `decodeAudioData` as a means to access raw samples from audio files in a faster than realtime manner. It only supports decoding entire audio files however which can take *huge* amounts of memory. For example, a 10 minute audio file with a sample rate of 44100 Hz, floating point samples, and stereo channels will occupy 44100 Hz * 600 seconds * 4 bytes * 2 channels = ~212 MB of memory when uncompressed.

In the future the [WebCodecs](https://github.com/WICG/web-codecs) proposal may address this oversight but until then this can be used as a more memory-friendly alternative to WebAudio's `decodeAudioData`.

### Notes
* Files in memory in browser environments since the filesystem is sandboxed.
* This library will automatically downmix multiple channels into a single channel by averaging samples across all channels.
* This library does **NOT** resample decoded audio, whereas `decodeAudioData` will automatically resample to the sample rate of its `AudioContext`.
* Sample position accuracy may be slightly off when decoding timestamp ranges due to timestamp precision and how FFmpeg's seek behaves. FFmpeg tries to seek to the closest frame possible for timestamps which may introduce an error of a few frames, where each frame contains a fixed (e.g 1024 samples) or dynamic number of samples depending on the audio file encoding.
* Performance is about ~2x slower than Chromium's implementation of `decodeAudioData`. Chromium's implementation also uses FFmpeg for decoding, but is able to run natively with threading and native optimizations enabled, while this library has them disabled for WebAssembly compatibility.

## Usage
```js
import { getAudioDecoder } from 'audio-file-decoder';

// decode-audio.wasm is an asset that must be included with your app
// it's recommended to use a loader that handles files/urls 
// (e.g file-loader for webpack) if bundling to ensure this gets included
import 'audio-file-decoder/decode-audio.wasm'; 

getAudioDecoder(file)
  .then(decoder => {
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
LGPL v2.1 or later