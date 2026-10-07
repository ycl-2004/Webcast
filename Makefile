SIMULATOR ?= iPhone 16 Pro
SIMULATOR_ID ?=
PROJECT = Webcast.xcodeproj
SCHEME = Webcast
BUILD_DIR = .build

.PHONY: generate build test demo

generate:
	xcodegen generate
	mkdir -p $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm
	cp Package.resolved $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath $(BUILD_DIR) CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination 'platform=iOS Simulator,name=$(SIMULATOR)' -derivedDataPath $(BUILD_DIR) CODE_SIGNING_ALLOWED=NO test

demo: build
	@test -n "$(SIMULATOR_ID)" || (printf '请指定已启动模拟器的 SIMULATOR_ID。\n'; exit 1)
	xcrun simctl install "$(SIMULATOR_ID)" $(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Webcast.app
	SIMCTL_CHILD_WEBCAST_OFFLINE_VALIDATION=1 SIMCTL_CHILD_WEBCAST_DEMO=1 xcrun simctl launch "$(SIMULATOR_ID)" dev.yc.Webcast
