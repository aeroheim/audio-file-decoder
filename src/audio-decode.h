#include <string>
#include <vector>
#ifdef __cplusplus
extern "C"
{
  #include <libavutil/opt.h>
  #include <libavcodec/avcodec.h>
  #include <libavformat/avformat.h>
  #include <libswresample/swresample.h>
}
#endif

int decode_audio(std::string& path, std::vector<float>& sample_buffer, int sample_rate, float start, float duration);
