#ifdef __cplusplus
extern "C"
{
  #include <libavutil/opt.h>
  #include <libavcodec/avcodec.h>
  #include <libavformat/avformat.h>
  #include <libswresample/swresample.h>
}
#endif
#include <string>
#include <vector>

struct DecodeAudioResult {
  int status;
  std::string error;
  std::vector<float> samples;
};

DecodeAudioResult decode_audio(const std::string& path, int sample_rate, float start, float duration);
