#ifdef __cplusplus
extern "C"
{
  #include <libavutil/opt.h>
  #include <libavcodec/avcodec.h>
  #include <libavformat/avformat.h>
}
#endif
#include <string>
#include <vector>

struct Status {
  int status;
  std::string error;
};

struct AudioProperties {
  Status status;
  std::string encoding;
  int sample_rate;
  int channels;
};

struct DecodeAudioResult {
  Status status;
  std::vector<float> samples;
};

AudioProperties get_properties(const std::string& path);
DecodeAudioResult decode_audio(const std::string& path, float start, float duration);
