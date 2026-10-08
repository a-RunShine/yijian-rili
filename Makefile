export LC_ALL := en_US.UTF-8

APP_NAME    := 一键日历
APP         := $(APP_NAME).app
BINARY      := $(APP_NAME)
SRC_PLIST   := Info.plist
ICON_FILE   := AppIcon.icns
BUILD_DIR   := .build/release
# 组装产物放在 .build/ 下而非仓库根：.build 已被 gitignore，
# swift package clean 也会一并清掉，源码目录保持干净
BUILD_APP   := $(BUILD_DIR)/$(APP)
APP_CONTENTS := $(BUILD_APP)/Contents

.PHONY: build bundle test run open clean all install uninstall verify-install

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
	codesign --force --deep -s - $(BUILD_APP)
	@echo "✅ Bundle 完成: $(BUILD_APP)"

test:
	swift test

# swift run 出来的是裸可执行文件，没有 app bundle 上下文，
# Info.plist 里的 NSCalendarsFullAccessUsageDescription / LSUIElement 都不生效。
# 调试请用 make open。
run:
	@echo "⚠️  swift run 无法提供 app bundle 上下文（日历权限声明、LSUIElement 都不生效）"
	@echo "    请改用: make open"
	@exit 1

open: bundle
	open $(BUILD_APP)

clean:
	swift package clean

# 安装用 ditto 覆盖而非 rm -rf + cp -R：
#   1. 变量出错时不会误删 /Applications 下的其他东西
#   2. ditto 保留扩展属性与资源叉（cp -R 会丢）
#   3. app 正在运行时也能覆盖（下次启动才生效）
# 注意：ditto 之后必须重新 codesign——签名 seal 记录了各资源的元数据，
# 复制过程会改动它们，直接验证会报 "a sealed resource is missing or invalid"
INSTALL_DIR := /Applications

install: bundle
	@test -d "$(INSTALL_DIR)" || { echo "❌ $(INSTALL_DIR) 不存在"; exit 1; }
	@test -f "$(BUILD_APP)/Contents/Info.plist" || { echo "❌ $(BUILD_APP) 不是有效的 app bundle"; exit 1; }
	@echo "→ ditto $(BUILD_APP) → $(INSTALL_DIR)/$(APP)"
	@ditto $(BUILD_APP) "$(INSTALL_DIR)/$(APP)"
	@codesign --force --deep -s - "$(INSTALL_DIR)/$(APP)"
	@codesign -v "$(INSTALL_DIR)/$(APP)" || { echo "❌ 安装后签名校验失败"; exit 1; }
	@echo "✅ 已安装到 $(INSTALL_DIR)/$(APP)"

verify-install:
	@codesign -v "$(INSTALL_DIR)/$(APP)" && echo "✅ 签名有效" || echo "❌ 签名无效"

uninstall:
	@test -d "$(INSTALL_DIR)/$(APP)" || { echo "未安装，跳过"; exit 0; }
	@rm -rf "$(INSTALL_DIR)/$(APP)"
	@echo "✅ 已卸载 $(INSTALL_DIR)/$(APP)"
