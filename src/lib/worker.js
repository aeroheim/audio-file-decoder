
const _decoder_memfs_path = 'audio';
let _decoder = undefined;

function throwError(type, error) {
  throw new Error(`${type}: ${error}`);
}

function initializeDecoder(messageType, wasm, fileData) {
  if (_decoder) {
    throwError(messageType, 'decoder is already initialized');
  }
  return Module({ locateFile: () => wasm })
    .then(m => {
      _decoder = m;
      _decoder.FS.writeFile(_decoder_memfs_path, new Int8Array(fileData));
      const { status: { status, error }, sampleRate, channelCount, encoding, duration } = _decoder.getProperties(_decoder_memfs_path);
      if (status < 0) {
        _decoder.FS.unlink(_decoder_memfs_path);
        throwError(messageType, error);
      }
      return {
        sampleRate,
        channelCount,
        encoding,
        duration,
      };
    });
}

function decodeAudio(messageType, start = 0, duration = -1) {
  if (!_decoder) {
    throwError(messageType, 'decoder is not initialized');
  }
  const { status: { status, error }, samples: vector } = _decoder.decodeAudio(_decoder_memfs_path, start, duration);
  if (status < 0) {
    vector.delete();
    throw `decodeAudioData error: ${error}`;
  }
  const samples = new Float32Array(vector.size());
  for (let i = 0; i < samples.length; i++) {
    samples[i] = vector.get(i);
  }
  // embind C++ wrapper objects must be deleted
  vector.delete();
  return samples;
}

onmessage = function(e) {
  const { type } = e.data;
  switch (type) {
    case 'initialize':
      const { wasm, fileData } = e.data;
      initializeDecoder(type, wasm, fileData)
        .then(({ sampleRate, channelCount, encoding, duration }) => postMessage({ type, sampleRate, channelCount, encoding, duration }));
      break;
    case 'decode':
      const { id, start, duration } = e.data;
      try {
        const samples = decodeAudio(type, start, duration);
        postMessage({ type, id, samples: samples.buffer }, [ samples.buffer ])
      } catch (err) {
        // need to return the id of the failed decode request, so use custom message instead of throwing error
        postMessage({ type: 'decodeError', id, error: err })
      }
      break;
    case 'dispose':
      if (_decoder) {
        _decoder.FS.unlink(_decoder_memfs_path);
      }
      break;
    default:
      throwError(type, 'unsupported decoder message');
      break;
  }
};
