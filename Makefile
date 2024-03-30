XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS"

BUILD_DIR=$(PWD)/Build
STARK_ACHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Stark/export.plist

all: build

build:
	@xcodebuild $(XCODEFLAGS) build

lint:
	@swift-format lint -r Stark/Source

format:
	@swift-format format -r -i Stark/Source

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ACHIVE)
	@xcodebuild -exportArchive -archivePath $(STARK_ACHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)

.PHONY: all build lint format archive
