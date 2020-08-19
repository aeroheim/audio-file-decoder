#include "audio-decode.h"
#include <emscripten/bind.h>
#include <iostream>
#include <cmath>

// TODO: for array, might need to pass in length as well
// TODO: better error handling (make sure to free resources on error)
DecodeAudioResult decode_audio(const std::string& path, int sample_rate, float start = 0, float duration = -1) {
  DecodeAudioResult result = { 0, "", std::vector<float>() };

  std::cout << "Analyzing file..." << std::endl;

  // get audio stream
  AVFormatContext* format = avformat_alloc_context();
  if ((result.status = avformat_open_input(&format, path.c_str(), nullptr, nullptr)) != 0) {
    result.error = "Failed to open file: " + path;
    return result;
  }
  if ((result.status = avformat_find_stream_info(format, nullptr)) < 0) {
    result.error = "Failed to get metadata from file: " + path;
    return result;
  }
  int audio_stream_index = -1;
  for (unsigned int i = 0; i < format->nb_streams; i++) {
    if (format->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
      audio_stream_index = i;
      break;
    }
  }
  if (audio_stream_index == -1) {
    result.status = -1;
    result.error = "Failed to get audio stream from file: " + path;
    return result;
  }
  AVStream* stream = format->streams[audio_stream_index];

  // get and initialize decoder
  AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
  if (!decoder) {
    result.status = -1;
    result.error = "Failed to decode file: " + path;
    return result;
  }
  AVCodecContext* codec = avcodec_alloc_context3(decoder);
  if (!codec) {
    result.status = -1;
    result.error = "Failed to allocate decoder memory for file: " + path;
    return result;
  }
  if ((result.status = avcodec_parameters_to_context(codec, stream->codecpar)) < 0) {
    result.error = "Failed to initialize decoder for file: " + path;
    return result;
  }
  if ((result.status = avcodec_open2(codec, decoder, nullptr)) < 0) {
    result.error = "Failed to open decoder for file: " + path;
    return result;
  }

  // TODO: consider what codec format you want (e.g s16 vs f64)
  std::cout << "Using the following codec: " << avcodec_get_name(codec->codec_id) << std::endl;

  // initialize resampler
  struct SwrContext* swr = swr_alloc();
  av_opt_set_int(swr, "in_channel_count", codec->channels, 0);
  av_opt_set_int(swr, "out_channel_count", 1, 0);
  av_opt_set_int(swr, "in_channel_layout", codec->channel_layout, 0);
  av_opt_set_int(swr, "out_channel_layout", AV_CH_LAYOUT_MONO, 0);
  av_opt_set_int(swr, "in_sample_rate", codec->sample_rate, 0);
  av_opt_set_int(swr, "out_sample_rate", sample_rate, 0);
  av_opt_set_sample_fmt(swr, "in_sample_fmt", codec->sample_fmt, 0);
  av_opt_set_sample_fmt(swr, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
  swr_init(swr);
  if (!swr_is_initialized(swr)) {
    result.status = -1;
    result.error = "Failed to initialize resampler for file: " + path;
    return result;
  }

  std::cout << "Decoding audio..." << std::endl;

  // begin decoding
  AVPacket* packet = av_packet_alloc();
  AVFrame* frame = av_frame_alloc();
  if (!frame) {
    result.status = -1;
    result.error = "Failed to allocate decoder frame";
    return result;
  }

  /*
  int sample_size = av_get_bytes_per_sample(codec->sample_fmt);
  int sample_count = std::ceil(duration_seconds * codec->sample_rate);
  std::cout << "bytes per sample: " << sample_size << std::endl;
  std::cout << "channels: " << codec->channels << std::endl;
  std::cout << "frame size: " << codec->frame_size << std::endl;
  std::cout << "estimated sample count: " << sample_count << std::endl;
  std::cout << "duration: " << duration_seconds << std::endl;
  */

  // seek to start timestamp
  int64_t start_timestamp = av_rescale(start, stream->time_base.den, stream->time_base.num);
  int64_t max_timestamp = av_rescale(format->duration / (float) AV_TIME_BASE, stream->time_base.den, stream->time_base.num);
  if ((result.status = av_seek_frame(format, audio_stream_index, std::min(start_timestamp, max_timestamp), AVSEEK_FLAG_ANY)) < 0) {
    result.error = "Failed to seek to start time: " + std::to_string(start);
    return result;
  }

  int status;
  int samples_to_decode = std::ceil(duration * codec->sample_rate);
  while ((status = av_read_frame(format, packet)) >= 0) {
    if (packet->stream_index == audio_stream_index) {
      // send compressed packet to decoder
      status = avcodec_send_packet(codec, packet);
      if (status == AVERROR(EAGAIN) || status == AVERROR_EOF) {
        continue;
      } else if (status < 0) {
        result.status = status;
        result.error = "Failed to decode packet!";
        return result;
      }

      // receive uncompressed frame from decoder
      while ((status = avcodec_receive_frame(codec, frame)) >= 0) {
        if (status == AVERROR(EAGAIN) || status == AVERROR_EOF) {
          break;
        } else if (status < 0) {
          result.status = status;
          result.error = "Failed to decode frame!";
          return result;
        }

        // resample and store samples
        float* buffer;
        av_samples_alloc((uint8_t**) &buffer, nullptr, 1, frame->nb_samples, AV_SAMPLE_FMT_FLT, 0);
        if ((result.status = swr_convert(swr, (uint8_t**) &buffer, frame->nb_samples, (const uint8_t**) frame->data, frame->nb_samples)) < 0) {
          result.error = "Failed to resample frame!";
          return result;
        }
        for (int i = 0; i < frame->nb_samples; i++) {
          result.samples.push_back(buffer[i]);
        }
        av_freep(&buffer);
      }

      // stop decoding if we have enough samples
      if (samples_to_decode >= 0 && (int) result.samples.size() >= samples_to_decode) {
        break;
      }
    }
  }

  std::cout << "Stored sample count: " << result.samples.size() << std::endl;

  // cleanup
  avformat_free_context(format);
  avcodec_free_context(&codec);
  av_packet_free(&packet);
  av_frame_free(&frame);
  swr_free(&swr);

  std::cout << "Success!" << std::endl;

  // success
  result.status = 0;
  return result;
}

DecodeAudioResult test_obj(std::string str, int val) {
  return {
    val,
    str,
    std::vector<float>({ 1, 2, 3, 4, 5 })
  };
}

EMSCRIPTEN_BINDINGS(my_module) {
  emscripten::value_object<DecodeAudioResult>("DecodeAudioResult")
    .field("status", &DecodeAudioResult::status)
    .field("error", &DecodeAudioResult::error)
    .field("samples", &DecodeAudioResult::samples);
  emscripten::function("decodeAudio", &decode_audio);
  emscripten::register_vector<float>("vector<float>");
}
