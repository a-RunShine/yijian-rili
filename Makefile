export LC_ALL := en_US.UTF-8

APP_NAME    := 一键日历
APP         := $(APP_NAME).app
BINARY      := $(APP_NAME)
SRC_PLIST   := Info.plist
ICON_FILE   := AppIcon.icns
BUILD_DIR   := .build/release
APP_CONTENTS := $(APP)/Contents

.PHONY: build bundle test run open clean all install

all: bundle

build:
	swift build -c release

bundle: build
	mkdir -p $(APP_CONTENTS)/MacOS
	mkdir -p $(APP_CONTENTS)/Resources/zh.lproj
	cp $(BUILD_DIR)/$(BINARY) $(APP_CONTENTS)/MacOS/$(BINARY)
	cp $(SRC_PLIST) $(APP_CONTENTS)/Info.plist
	cp AppIcon.icns $(APP_CONTENTS)/Resources/AppIcon.icns
	cp -R $(BUILD_DIR)/$(BINARY)_$(BINARY).bundle $(APP_CONTENTS)/Resources/
	cp Sources/$(APP_NAME)/Resources/zh.lproj/Localizable.strings $(APP_CONTENTS)/Resources/zh.lproj/Localizable.strings
	codesign --force --deep -s - $(APP)
	@echo "✅ Bundle 完成: $(APP)"

test:
	swift test

run:
	swift run

open: bundle
	open $(APP)

clean:
	swift package clean
install: bundle
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/$(APP)
	@echo "✅ 已安装到 /Applications/$(APP)"
