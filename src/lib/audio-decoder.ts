import decodeAudioModule from '../wasm/decode-audio';
import { readBuffer } from './utils';

/**
 * Creates an AudioDecoder for the given audio file.
 * Make sure to call dispose() when no longer needed to free its resources.
 * @param {string} wasm - a path or inlined version to/of decode-audio.wasm
 * @param {File | ArrayBuffer} fileOrBuffer - the audio file or buffer to process
 * @returns Promise
 */
function getAudioDecoder(wasm: string, fileOrBuffer: File | ArrayBuffer): Promise<AudioDecoder> {
  // load a new instance of the wasm module per file
  // this is done to reset the allocated heap per file, as wasm doesn't have a way to shrink the heap manually
  return Promise.all([decodeAudioModule({ locateFile: () => wasm }), readBuffer(fileOrBuffer)])
    .then(results => new AudioDecoder(results[0], results[1]));
}

/**
 * A disposable class for decoding an audio file.
 * Should only be instantiated with the getAudioDecoder() factory function.
 * Make sure to call dispose() when no longer needed to free its resources.
 */
class AudioDecoder {
  private static MEMFS_PATH = 'audio';
  private _module;
  private _sampleRate: number;
  private _channelCount: number;
  private _encoding: string;
  private _duration: number;

  constructor(m, data: ArrayBuffer) {
    this._module = m;
    this._module.FS.writeFile(AudioDecoder.MEMFS_PATH, new Int8Array(data));

    // read file properties
    const { status: { status, error }, sampleRate, channelCount, encoding, duration } = this._module.getProperties(AudioDecoder.MEMFS_PATH)
    if (status < 0) {
      throw `AudioDecoder initialization error: ${error}`;
    }
    this._sampleRate = sampleRate;
    this._channelCount = channelCount;
    this._encoding = encoding;
    this._duration = duration;
  }

  get sampleRate(): number {
    return this._sampleRate;
  }

  get channelCount(): number {
    return this._channelCount;
  }

  get encoding(): string {
    return this._encoding;
  }

  get duration(): number {
    return this._duration;
  }

  /**
   * Decodes audio from the currently loaded file.
   * @param {number} start=0 - the timestamp in seconds to start decoding at.
   * @param {number} duration=-1 - the length in seconds to decode, or -1 to decode until the end of the file.
   * @returns Float32Array
   */
  decodeAudioData(start = 0, duration = -1): Float32Array {
    const { status: { status, error }, samples: vector } = this._module.decodeAudio(AudioDecoder.MEMFS_PATH, start, duration);
    if (status < 0) {
      vector.delete();
      throw `decodeAudioData error: ${error}`;
    }

    const samples = new Float32Array(vector.size());
    for (let i = 0; i < samples.length; i++) {
      samples[i] = vector.get(i);
    }

    // objects from C++ must be deleted explicitly
    // see https://emscripten.org/docs/porting/connecting_cpp_and_javascript/embind.html#memory-management
    vector.delete();
    return samples;
  }

  /**
   * Disposes the AudioDecoder and frees its resources.
   * Must be called after the decoder is no longer needed.
   */
  dispose() {
    this._module.FS.unlink(AudioDecoder.MEMFS_PATH);
  }
}

export {
  getAudioDecoder,
  AudioDecoder,
};

export default getAudioDecoder;
