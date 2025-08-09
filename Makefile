XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS"

BUILD_DIR=$(PWD)/Build
STARK_ACHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Stark/export.plist

format:
	@swift format format -r -i Stark

lint:
	@swift format lint -r Stark

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ACHIVE) DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
	@xcodebuild -exportArchive -archivePath $(STARK_ACHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)
	@cp -R $(STARK_ACHIVE)/dSYMs $(BUILD_DIR)/dSYMs

.DEFAULT_GOAL := build
.PHONY: format lint build archive
