#include "audio-decode.h"

int main(int argc, char** argv) {
  std::string path(argv[1]);
  decode_audio(path, 44100, 0, -1);
  return 0;
}