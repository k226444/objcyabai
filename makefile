FRAMEWORK_PATH = -F/System/Library/PrivateFrameworks
FRAMEWORK      = -framework Carbon -framework Cocoa -framework CoreServices -framework SkyLight
BUILD_FLAGS    = -std=c99 -Wall -g -O2 -fvisibility=hidden -mmacosx-version-min=11.0 -fno-objc-arc -arch x86_64 -arch arm64
BUILD_PATH     = ./bin
DOC_PATH       = ./doc
SCRIPT_PATH    = ./scripts
ASSET_PATH     = ./assets
SMP_PATH       = ./examples
ARCH_PATH      = ./archive
OSAX_SRC       = ./src/osax/payload_bin.m ./src/osax/loader_bin.m
YABAI_SRC      = ./src/manifest.m $(OSAX_SRC)
OSAX_PATH      = ./src/osax
BINS           = $(BUILD_PATH)/yabai

.PHONY: all clean install sign archive man

all: clean-build $(BINS)

install: BUILD_FLAGS=-std=c99 -Wall -DNDEBUG -O2 -fvisibility=hidden -mmacosx-version-min=11.0 -fno-objc-arc -arch x86_64 -arch arm64
install: clean-build $(BINS)

$(OSAX_SRC): $(OSAX_PATH)/loader.m $(OSAX_PATH)/payload.m
	xcrun clang $(OSAX_PATH)/payload.m -shared -fPIC -O2 -mmacosx-version-min=11.0 -arch x86_64 -arch arm64e -o $(OSAX_PATH)/payload $(FRAMEWORK_PATH) -framework SkyLight -framework Foundation -framework Carbon
	xcrun clang $(OSAX_PATH)/loader.m -O2 -mmacosx-version-min=11.0 -arch x86_64 -arch arm64e -o $(OSAX_PATH)/loader -framework Cocoa
	xxd -i -a $(OSAX_PATH)/payload $(OSAX_PATH)/payload_bin.m
	xxd -i -a $(OSAX_PATH)/loader $(OSAX_PATH)/loader_bin.m
	rm -f $(OSAX_PATH)/payload
	rm -f $(OSAX_PATH)/loader

man:
	asciidoctor -b manpage $(DOC_PATH)/yabai.asciidoc -o $(DOC_PATH)/yabai.1

icon:
	python3 $(SCRIPT_PATH)/seticon.py $(ASSET_PATH)/icon/2x/icon-512px@2x.png $(BUILD_PATH)/yabai

archive: man install sign icon
	rm -rf $(ARCH_PATH)
	mkdir -p $(ARCH_PATH)
	cp -r $(BUILD_PATH) $(ARCH_PATH)/
	cp -r $(DOC_PATH) $(ARCH_PATH)/
	cp -r $(SMP_PATH) $(ARCH_PATH)/
	tar -cvzf $(BUILD_PATH)/$(shell $(BUILD_PATH)/yabai --version).tar.gz $(ARCH_PATH)
	rm -rf $(ARCH_PATH)

sign:
	codesign -fs "yabai-cert" $(BUILD_PATH)/yabai

clean-build:
	rm -rf $(BUILD_PATH)

clean: clean-build
	rm -f $(OSAX_SRC)

$(BUILD_PATH)/yabai: $(YABAI_SRC)
	mkdir -p $(BUILD_PATH)
	xcrun clang $^ $(BUILD_FLAGS) $(FRAMEWORK_PATH) $(FRAMEWORK) -o $@
