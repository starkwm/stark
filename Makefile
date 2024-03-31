XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS"

BUILD_DIR=$(PWD)/Build
STARK_ACHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Stark/export.plist

format:
	@swift-format format -r -i Stark/Source

lint:
	@swift-format lint -r Stark/Source

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ACHIVE)
	@xcodebuild -exportArchive -archivePath $(STARK_ACHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)

.DEFAULT_GOAL := build
.PHONY: format lint build archive
