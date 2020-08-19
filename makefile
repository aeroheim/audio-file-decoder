# tool macros
CC        := emcc
CCFLAG    := -Wall -Os --no-entry -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s STRICT=1 -s MALLOC=emmalloc -s MODULARIZE=1 -s EXPORT_ES6=1 --bind
DBGFLAG   := -g
LDFLAG    := `PKG_CONFIG_PATH="$$HOME/ffmpeg_build/lib/pkgconfig" pkg-config --cflags --libs libavcodec libavformat libswresample libavutil`
CCOBJFLAG := $(CCFLAG) -c

# path macros
BIN_PATH := dist
OBJ_PATH := obj
SRC_PATH := src
DBG_PATH := debug

# compile macros
TARGET_NAME := decode-audio
TARGET := $(BIN_PATH)/$(TARGET_NAME).js
TARGET_DEBUG := $(DBG_PATH)/$(TARGET_NAME)
MAIN_SRC := $(SRC_PATH)/$(TARGET_NAME).cpp

# src files & obj files
SRC := $(foreach x, $(SRC_PATH), $(wildcard $(addprefix $(x)/*,.c*)))
OBJ := $(addprefix $(OBJ_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))
OBJ_DEBUG := $(addprefix $(DBG_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))

# clean files list
DISTCLEAN_LIST := $(OBJ) \
                  $(OBJ_DEBUG)
CLEAN_LIST := $(TARGET) \
			  $(TARGET_DEBUG) \
			  $(DISTCLEAN_LIST)

# default rule
default: all

# non-phony targets
$(TARGET): $(OBJ)
	$(CC) $(CCFLAG) -o $@ $? $(LDFLAG)

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c*
	$(CC) $(CCOBJFLAG) -o $@ $< $(LDFLAG)

$(DBG_PATH)/%.o: $(SRC_PATH)/%.c*
	$(CC) $(CCOBJFLAG) $(DBGFLAG) -o $@ $< $(LDFLAG)

$(TARGET_DEBUG): $(OBJ_DEBUG)
	$(CC) $(CCFLAG) $(DBGFLAG) $? -o $@ $(LDFLAG)

# phony rules
.PHONY: all
all: $(TARGET)

.PHONY: debug
debug: $(TARGET_DEBUG)

.PHONY: clean
clean:
	@echo CLEAN $(CLEAN_LIST)
	@rm -f $(CLEAN_LIST)

.PHONY: distclean
distclean:
	@echo CLEAN $(DISTCLEAN_LIST)
	@rm -f $(DISTCLEAN_LIST)