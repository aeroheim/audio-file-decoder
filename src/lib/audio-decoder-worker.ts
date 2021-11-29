// @ts-ignore
import DecodeAudioWorker from 'web-worker:../wasm/decode-audio-worker';
import { DecodeAudioOptions } from './types';
import { readBuffer } from './utils';

enum AudioDecoderMessageType {
  Initialize = 'initialize',
  Decode = 'decode',
  DecodeError = 'decodeError',
  Dispose = 'dispose',
}

/**
 * Creates an AudioDecoderWorker for the given audio file.
 * Make sure to call dispose() when no longer needed to free its resources.
 * @param {string} wasm - a path or inlined version to/of decode-audio.wasm
 * @param {File | ArrayBuffer} fileOrBuffer - the audio file or buffer to process
 * @returns Promise
 */
function getAudioDecoderWorker(wasm: string, fileOrBuffer: File | ArrayBuffer): Promise<AudioDecoderWorker> {
  const worker = new DecodeAudioWorker();
  return new Promise<AudioDecoderWorker>((resolve, reject) => {
    readBuffer(fileOrBuffer)
      .then(fileData => {
        worker.onmessage = (e: MessageEvent) => {
          const { type, sampleRate, channelCount, encoding, duration } = e.data;
          if (type === AudioDecoderMessageType.Initialize) {
            resolve(new AudioDecoderWorker(worker, {
              sampleRate,
              channelCount,
              encoding,
              duration,
            }));
          } else {
            reject('Failed to initialize decoder worker');
          }
        };
        worker.onerror = (err: ErrorEvent) => reject(`Failed to initialize decoder worker: ${err.message}`);

        // initialize decoder thread
        worker.postMessage({ type: AudioDecoderMessageType.Initialize, wasm: new URL(wasm, window.location.origin).href, fileData }, [ fileData ]);
      })
      .catch(err => reject(err));
  });
}

interface AudioFileProperties {
  sampleRate: number;
  channelCount: number;
  encoding: string;
  duration: number;
}

/**
 * A disposable class for decoding an audio file asynchronously.
 * Should only be instantiated with the getAudioDecoderWorker() factory function.
 * Make sure to call dispose() when no longer needed to free its resources.
 */
class AudioDecoderWorker {
  private _worker: Worker;
  private _properties: AudioFileProperties;

  constructor(worker: Worker, properties: AudioFileProperties) {
    this._worker = worker;
    this._properties = properties;
  }

  get sampleRate(): number {
    return this._properties.sampleRate;
  }

  get channelCount(): number {
    return this._properties.channelCount;
  }

  get encoding(): string {
    return this._properties.encoding;
  }

  get duration(): number {
    return this._properties.duration;
  }

  /**
   * Decodes audio asynchronously from the currently loaded file.
   * @param {number} start=0 - the timestamp in seconds to start decoding at.
   * @param {number} duration=-1 - the length in seconds to decode, or -1 to decode until the end of the file.
   * @param {DecodeAudioOptions} options={} - additional options for decoding.
   * @returns Float32Array
   */
  decodeAudioData(start = 0, duration = -1, options: DecodeAudioOptions = {}): Promise<Float32Array> {
    return new Promise<Float32Array>((resolve, reject) => {
      // generate a unique id for the current decode request
      // this prevents race conditions when multiple decode requests are queued
      const requestId = Date.now() + Math.random();
      const onDecode = (e: MessageEvent) => {
        const { type, id, samples, error } = e.data;
        if (type === AudioDecoderMessageType.Decode && id === requestId) {
          this._worker.removeEventListener('message', onDecode);
          resolve(new Float32Array(samples));
        } else if (type === AudioDecoderMessageType.DecodeError && id === requestId) {
          this._worker.removeEventListener('message', onDecode);
          reject(error);
        }
      };

      this._worker.addEventListener('message', onDecode);
      this._worker.postMessage({ type: AudioDecoderMessageType.Decode, id: requestId, start, duration, options });
    });
  }

  /**
   * Disposes the AudioDecoder and frees its resources.
   * Must be called after the decoder is no longer needed.
   */
  dispose() {
    this._worker.postMessage({ type: AudioDecoderMessageType.Dispose });
    this._worker.terminate();
  }
}

export {
  getAudioDecoderWorker,
  AudioDecoderWorker,
};

export default getAudioDecoderWorker;
