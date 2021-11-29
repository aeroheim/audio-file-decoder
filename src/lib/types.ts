
interface DecodeAudioOptions {
  // whether to decode multiple channels.
  // if set to true, the resulting array will contain interleaved samples from each channel.
  // -  using the channel count, samples can be accessed using samples[sample * channelCount + channel]
  // if set to false, the resulting will contain downmixed samples averaged from each channel.
  // - samples can be accessed using samples[sample]
  multiChannel?: boolean;
}

export {
  DecodeAudioOptions,
}
