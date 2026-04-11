APP_NAME=Spk
BUILD_DIR=.build/release
APP_BUNDLE=$(APP_NAME).app
CONTENTS=$(APP_BUNDLE)/Contents
MACOS=$(CONTENTS)/MacOS
RESOURCES=$(CONTENTS)/Resources

.PHONY: all build package sign clean

all: build package sign

build:
	swift build -c release

package:
	mkdir -p $(MACOS)
	mkdir -p $(RESOURCES)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS)/
	cp Sources/spk/Info.plist $(CONTENTS)/
	cp -R Sources/spk/Resources/* $(RESOURCES)/

sign:
	codesign --force --options runtime --entitlements entitlements.plist --sign - $(APP_BUNDLE)

clean:
	rm -rf .build $(APP_BUNDLE)

run: all
	./$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
