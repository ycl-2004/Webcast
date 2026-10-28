SIMULATOR ?= iPhone 17
SIMULATOR_ID ?=
SIMULATOR_OS ?= latest
-include .device.mk
PROJECT = Webcast.xcodeproj
SCHEME = Webcast
CONFIGURATION ?= Release
BUILD_DIR ?= .build
PACKAGE_DIR ?= $(BUILD_DIR)/OfficialSourcePackages
DEVICE_BUILD_DIR ?= .build-device
SIM_PRODUCTS = $(abspath $(BUILD_DIR))/Build/Products
DEVICE_PRODUCTS = $(abspath $(DEVICE_BUILD_DIR))/Build/Products
SIM_APP = $(SIM_PRODUCTS)/$(CONFIGURATION)-iphonesimulator/Webcast.app
DEVICE_UDID ?=
DEVICE_TEAM ?=
DEVICE_APP = $(DEVICE_PRODUCTS)/$(CONFIGURATION)-iphoneos/Webcast.app
ifneq ($(strip $(SIMULATOR_ID)),)
TEST_DESTINATION = platform=iOS Simulator,id=$(SIMULATOR_ID)
else
TEST_DESTINATION = platform=iOS Simulator,name=$(SIMULATOR),OS=$(SIMULATOR_OS)
endif
# 指定 DEVICE_TEAM 时自动附加开发团队签名参数
ifdef DEVICE_TEAM
SIGN_ARGS = DEVELOPMENT_TEAM=$(DEVICE_TEAM)
endif

.PHONY: generate build release check-release test demo device-build device-install device

generate:
	xcodegen generate
	mkdir -p $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm
	cp Package.resolved $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -clonedSourcePackagesDirPath $(PACKAGE_DIR) -configuration $(CONFIGURATION) -destination 'generic/platform=iOS Simulator' -derivedDataPath $(BUILD_DIR) SYMROOT="$(SIM_PRODUCTS)" OBJROOT="$(abspath $(BUILD_DIR))/Build/Intermediates.noindex" CODE_SIGNING_ALLOWED=NO build

release: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -clonedSourcePackagesDirPath $(PACKAGE_DIR) -configuration Release -destination 'generic/platform=iOS' -derivedDataPath $(DEVICE_BUILD_DIR) SYMROOT="$(DEVICE_PRODUCTS)" OBJROOT="$(abspath $(DEVICE_BUILD_DIR))/Build/Intermediates.noindex" CODE_SIGNING_ALLOWED=NO build

check-release:
	$(MAKE) build CONFIGURATION=Release
	python3 scripts/verify_bundle.py "$(SIM_PRODUCTS)/Release-iphonesimulator/Webcast.app"

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -clonedSourcePackagesDirPath $(PACKAGE_DIR) -configuration Debug -destination '$(TEST_DESTINATION)' -derivedDataPath $(BUILD_DIR) SYMROOT="$(SIM_PRODUCTS)" OBJROOT="$(abspath $(BUILD_DIR))/Build/Intermediates.noindex" CODE_SIGNING_ALLOWED=NO test

demo:
	@test -n "$(SIMULATOR_ID)" || { printf '请指定已启动模拟器的 SIMULATOR_ID。\n'; exit 1; }
	$(MAKE) build CONFIGURATION=Debug
	xcrun simctl install "$(SIMULATOR_ID)" "$(SIM_PRODUCTS)/Debug-iphonesimulator/Webcast.app"
	SIMCTL_CHILD_WEBCAST_OFFLINE_VALIDATION=1 SIMCTL_CHILD_WEBCAST_DEMO=1 xcrun simctl launch "$(SIMULATOR_ID)" dev.yc.Webcast

# 安装前需在 Xcode 配置自己的签名团队与设备。默认安装 Release。
device-build: generate
	@test -n "$(DEVICE_UDID)" || { printf '请指定 DEVICE_UDID，并在本地签名配置中设置团队。\n'; exit 1; }
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -clonedSourcePackagesDirPath $(PACKAGE_DIR) -configuration $(CONFIGURATION) \
		-destination 'platform=iOS,id=$(DEVICE_UDID)' -derivedDataPath $(DEVICE_BUILD_DIR) SYMROOT="$(DEVICE_PRODUCTS)" OBJROOT="$(abspath $(DEVICE_BUILD_DIR))/Build/Intermediates.noindex" \
		CODE_SIGNING_ALLOWED=YES $(SIGN_ARGS) build

device-install: device-build
	xcrun devicectl device install app --device $(DEVICE_UDID) "$(DEVICE_APP)"

device: device-install
	xcrun devicectl device process launch --device $(DEVICE_UDID) dev.yc.Webcast
