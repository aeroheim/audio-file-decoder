#include <iostream>
#include <cmath>
#include "audio-decode.h"

// TODO: figure out best way to communicate errors for wasm
// TODO: handle bindings/types for wasm
// TODO: for array, might need to pass in length as well
// TODO: better error handling (make sure to free resources on error)
int decode_audio(std::string& path, std::vector<float>& sample_buffer, int sample_rate, float start = 0, float duration = -1) {
  std::cout << "Analyzing file..." << std::endl;

  // get audio stream
  AVFormatContext* format = avformat_alloc_context();
  if (avformat_open_input(&format, path.c_str(), nullptr, nullptr) != 0) {
    std::cerr << "Failed to open file: " << path << std::endl;
    return -1;
  }
  if (avformat_find_stream_info(format, nullptr) < 0) {
    std::cerr << "Failed to get metadata from file: " << path << std::endl;
    return -1;
  }
  int stream_index = -1;
  for (unsigned int i = 0; i < format->nb_streams; i++) {
    if (format->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
      stream_index = i;
      break;
    }
  }
  if (stream_index == -1) {
    std::cerr << "Failed to get audio stream from file: " << path << std::endl;
    return -1;
  }
  AVStream* stream = format->streams[stream_index];

  // get and initialize decoder
  AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
  if (!decoder) {
    std::cerr << "Failed to decode file: " << path << std::endl;
    return -1;
  }
  AVCodecContext* codec = avcodec_alloc_context3(decoder);
  if (!codec) {
    std::cerr << "Failed to allocate decoder memory for file: " << path << std::endl;
    return -1;
  }
  if (avcodec_parameters_to_context(codec, stream->codecpar) < 0) {
    std::cerr << "Failed to initialize decoder for file: " << path << std::endl;
    return -1;
  }
  if (avcodec_open2(codec, decoder, nullptr) < 0) {
    std::cerr << "Failed to open decoder for file: " << path << std::endl;
    return -1;
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
    std::cerr << "Failed to resample file: " << path << std::endl;
    return -1;
  }

  std::cout << "Decoding audio..." << std::endl;

  // begin decoding
  AVPacket* packet = av_packet_alloc();
  AVFrame* frame = av_frame_alloc();
  if (!frame) {
    std::cerr << "Failed to allocate decoder frame" << std::endl;
    return -1;
  }

  int sample_size = av_get_bytes_per_sample(codec->sample_fmt);
  std::cout << "bytes per sample: " << sample_size << std::endl;
  std::cout << "channels: " << codec->channels << std::endl;
  std::cout << "frame size: " << codec->frame_size << std::endl;

  float duration_seconds = format->duration / (float) AV_TIME_BASE;
  std::cout << "duration: " << duration_seconds << std::endl;

  int sample_count = std::ceil(duration_seconds * codec->sample_rate);
  std::cout << "estimated sample count: " << sample_count << std::endl;

  // seek to start timestamp
  int64_t start_timestamp = av_rescale(start, stream->time_base.den, stream->time_base.num);
  int64_t max_timestamp = av_rescale(duration_seconds, stream->time_base.den, stream->time_base.num);
  if (av_seek_frame(format, stream_index, std::min(start_timestamp, max_timestamp), AVSEEK_FLAG_ANY) < 0) {
    std::cerr << "Failed to seek to start time: " << start << std::endl;
    return -1;
  }

  int status;
  int samples_to_decode = std::ceil(duration * codec->sample_rate);
  while ((status = av_read_frame(format, packet)) >= 0) {
    if (packet->stream_index == stream_index) {
      // send compressed packet to decoder
      status = avcodec_send_packet(codec, packet);
      if (status == AVERROR(EAGAIN) || status == AVERROR_EOF) {
        continue;
      } else if (status < 0) {
        std::cerr << "Failed to decode packet: " << status << std::endl;
        return -1;
      }

      // receive uncompressed frame from decoder
      while ((status = avcodec_receive_frame(codec, frame)) >= 0) {
        if (status == AVERROR(EAGAIN) || status == AVERROR_EOF) {
          break;
        } else if (status < 0) {
          std::cerr << "Failed to decode frame" << std::endl;
          return -1;
        }

        // resample and store samples
        float* buffer;
        av_samples_alloc((uint8_t**) &buffer, nullptr, 1, frame->nb_samples, AV_SAMPLE_FMT_FLT, 0);
        if (swr_convert(swr, (uint8_t**) &buffer, frame->nb_samples, (const uint8_t**) frame->data, frame->nb_samples) < 0) {
          std::cerr << "Failed to resample frame" << std::endl;
          return -1;
        }

        for (int i = 0; i < frame->nb_samples; i++) {
          sample_buffer.push_back(buffer[i]);
        }

        av_freep(&buffer);
      }

      // stop decoding if necessary
      if (samples_to_decode >= 0 && (int) sample_buffer.size() >= samples_to_decode) {
        break;
      }
    }
  }

  std::cout << "Stored sample count: " << sample_buffer.size() << std::endl;

  // cleanup
  av_packet_free(&packet);
  av_frame_free(&frame);
  swr_free(&swr);
  avcodec_close(codec);
  avformat_free_context(format);

  std::cout << "Success!" << std::endl;

  // success
  return 0;
}
