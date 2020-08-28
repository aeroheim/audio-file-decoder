#include "audio-decode.h"
#include <emscripten/bind.h>
#include <limits>
#include <cmath>

/*
 * Reads the samples from a frame and puts them into the destination vector.
 * Samples will be stored as floats in the range of -1 to 1.
 * If the frame has multiple channels, samples will be averaged across all channels.
 */
template <typename SampleType>
void read_samples(AVFrame* frame, std::vector<float>& dest, bool is_planar) {
  // use a midpoint offset between min/max for unsigned integer types
  SampleType min_numeric = std::numeric_limits<SampleType>::min();
  SampleType max_numeric = std::numeric_limits<SampleType>::max();
  SampleType zero_sample = min_numeric == 0 ? max_numeric / 2 + 1 : 0;

  for (int i = 0; i < frame->nb_samples; i++) {
    float sample = 0.0f;
    for (int j = 0; j < frame->channels; j++) {
      sample += is_planar 
        ? (
          static_cast<float>(reinterpret_cast<SampleType*>(frame->extended_data[j])[i] - zero_sample) /
          static_cast<float>(max_numeric - zero_sample)
        )
        : (
          static_cast<float>(reinterpret_cast<SampleType*>(frame->data[0])[i * frame->channels + j] - zero_sample) / 
          static_cast<float>(max_numeric - zero_sample)
        );
    }
    sample /= frame->channels;
    dest.push_back(sample);
  }
}

template <>
void read_samples<float>(AVFrame* frame, std::vector<float>& dest, bool is_planar) {
  for (int i = 0; i < frame->nb_samples; i++) {
    float sample = 0.0f;
    for (int j = 0; j < frame->channels; j++) {
      sample += is_planar 
        ? reinterpret_cast<float*>(frame->extended_data[j])[i]
        : reinterpret_cast<float*>(frame->data[0])[i * frame->channels + j];
    }
    sample /= frame->channels;
    dest.push_back(sample);
  }
}

int read_samples(AVFrame* frame, AVSampleFormat format, std::vector<float>& dest) {
  bool is_planar = av_sample_fmt_is_planar(format);
  switch (format) {
    case AV_SAMPLE_FMT_U8:
    case AV_SAMPLE_FMT_U8P:
      read_samples<uint8_t>(frame, dest, is_planar);
      return 0;
    case AV_SAMPLE_FMT_S16:
    case AV_SAMPLE_FMT_S16P:
      read_samples<int16_t>(frame, dest, is_planar);
      return 0;
    case AV_SAMPLE_FMT_S32:
    case AV_SAMPLE_FMT_S32P:
      read_samples<int32_t>(frame, dest, is_planar);
      return 0;
    case AV_SAMPLE_FMT_FLT:
    case AV_SAMPLE_FMT_FLTP:
      read_samples<float>(frame, dest, is_planar);
      return 0;
    default:
      return -1;
  }
}

std::string get_error_str(int status) {
  char errbuf[AV_ERROR_MAX_STRING_SIZE];
  av_make_error_string(errbuf, AV_ERROR_MAX_STRING_SIZE, status);
  return std::string(errbuf);
}

Status open_audio_stream(const std::string& path, AVFormatContext*& format, AVCodecContext*& codec, int& audio_stream_index) {
  Status status;
  format = avformat_alloc_context();
  if ((status.status = avformat_open_input(&format, path.c_str(), nullptr, nullptr)) != 0) {
    status.error = "avformat_open_input: " + get_error_str(status.status);
    return status;
  }
  if ((status.status = avformat_find_stream_info(format, nullptr)) < 0) {
    status.error = "avformat_find_stream_info: " + get_error_str(status.status);
    return status;
  }
  AVCodec* decoder;
  if ((audio_stream_index = av_find_best_stream(format, AVMEDIA_TYPE_AUDIO, -1, -1, &decoder, -1)) < 0) {
    status.status = audio_stream_index;
    status.error = "av_find_best_stream: Failed to locate audio stream";
    return status;
  }
  codec = avcodec_alloc_context3(decoder);
  if (!codec) {
    status.status = -1;
    status.error = "avcodec_alloc_context3: Failed to allocate decoder";
    return status;
  }
  if ((status.status = avcodec_parameters_to_context(codec, format->streams[audio_stream_index]->codecpar)) < 0) {
    status.error = "avcodec_parameters_to_context: " + get_error_str(status.status);
    return status;
  }
  if ((status.status = avcodec_open2(codec, decoder, nullptr)) < 0) {
    status.error = "avcodec_open2: " + get_error_str(status.status);
    return status;
  }

  return status;
}

void close_audio_stream(AVFormatContext* format, AVCodecContext* codec, AVFrame* frame, AVPacket* packet) {
  if (format) {
    avformat_close_input(&format);
  }
  if (codec) {
    avcodec_free_context(&codec);
  }
  if (packet) {
    av_packet_free(&packet);
  }
  if (frame) {
    av_frame_free(&frame);
  }
}

AudioProperties get_properties(const std::string& path) {
  Status status;
  AVFormatContext* format;
  AVCodecContext* codec;
  int audio_stream_index;

  status = open_audio_stream(path, format, codec, audio_stream_index);
  if (status.status < 0) {
    close_audio_stream(format, codec, nullptr, nullptr);
    return { status };
  }

  AudioProperties properties = {
    status,
    avcodec_get_name(codec->codec_id),
    codec->sample_rate,
    codec->channels
  };

  close_audio_stream(format, codec, nullptr, nullptr);
  return properties;
}

DecodeAudioResult decode_audio(const std::string& path, float start = 0, float duration = -1) {
  Status status;
  AVFormatContext* format;
  AVCodecContext* codec;
  int audio_stream_index;

  status = open_audio_stream(path, format, codec, audio_stream_index);
  if (status.status < 0) {
    close_audio_stream(format, codec, nullptr, nullptr);
    // check if vector is undefined/null in js
    return { status };
  }

  // seek to start timestamp
  AVStream* stream = format->streams[audio_stream_index];
  int64_t start_timestamp = av_rescale(start, stream->time_base.den, stream->time_base.num);
  int64_t max_timestamp = av_rescale(format->duration / static_cast<float>(AV_TIME_BASE), stream->time_base.den, stream->time_base.num);
  if ((status.status = av_seek_frame(format, audio_stream_index, std::min(start_timestamp, max_timestamp), AVSEEK_FLAG_ANY)) < 0) {
    close_audio_stream(format, codec, nullptr, nullptr);
    status.error = "av_seek_frame: " + get_error_str(status.status) + ". timestamp: " + std::to_string(start);
    return { status };
  }

  AVPacket* packet = av_packet_alloc();
  AVFrame* frame = av_frame_alloc();
  if (!packet || !frame) {
    close_audio_stream(format, codec, frame, packet);
    status.status = -1;
    status.error = "av_packet_alloc/av_frame_alloc: Failed to allocate decoder frame";
    return { status };
  }

  // decode loop
  std::vector<float> samples;
  int samples_to_decode = std::ceil(duration * codec->sample_rate);
  while ((status.status = av_read_frame(format, packet)) >= 0) {
    if (packet->stream_index == audio_stream_index) {
      // send compressed packet to decoder
      status.status = avcodec_send_packet(codec, packet);
      if (status.status == AVERROR(EAGAIN) || status.status == AVERROR_EOF) {
        continue;
      } else if (status.status < 0) {
        close_audio_stream(format, codec, frame, packet);
        status.error = "avcodec_send_packet: " + get_error_str(status.status);
        return { status };
      }

      // receive uncompressed frame from decoder
      while ((status.status = avcodec_receive_frame(codec, frame)) >= 0) {
        if (status.status == AVERROR(EAGAIN) || status.status == AVERROR_EOF) {
          break;
        } else if (status.status < 0) {
          close_audio_stream(format, codec, frame, packet);
          status.error = "avcodec_receive_frame: " + get_error_str(status.status);
          return { status };
        }

        // read samples from frame into result
        read_samples(frame, codec->sample_fmt, samples);
        av_frame_unref(frame);
      }

      av_packet_unref(packet);

      // stop decoding if we have enough samples
      if (samples_to_decode >= 0 && static_cast<int>(samples.size()) >= samples_to_decode) {
        break;
      }
    }
  }

  // cleanup
  close_audio_stream(format, codec, frame, packet);

  // success
  status.status = 0;
  return { status, samples };
}

EMSCRIPTEN_BINDINGS(my_module) {
  emscripten::value_object<Status>("Status")
    .field("status", &Status::status)
    .field("error", &Status::error);
  emscripten::value_object<AudioProperties>("AudioProperties")
    .field("status", &AudioProperties::status)
    .field("sampleRate", &AudioProperties::sample_rate)
    .field("channelCount", &AudioProperties::channels)
    .field("encoding", &AudioProperties::encoding);
  emscripten::value_object<DecodeAudioResult>("DecodeAudioResult")
    .field("status", &DecodeAudioResult::status)
    .field("samples", &DecodeAudioResult::samples);
  emscripten::function("getProperties", &get_properties);
  emscripten::function("decodeAudio", &decode_audio);
  emscripten::register_vector<float>("vector<float>");
}
