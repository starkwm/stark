XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS,arch=arm64"

BUILD_DIR=$(PWD)/Build
STARK_ARCHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Stark/export.plist

format:
	@swift format format -r -i Stark StarkTests

lint:
	@swift format lint -r Stark StarkTests

build:
	@xcodebuild $(XCODEFLAGS) build

test:
	@xcodebuild $(XCODEFLAGS) test

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ARCHIVE) DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
	@xcodebuild -exportArchive -archivePath $(STARK_ARCHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)

clean:
	@xcodebuild $(XCODEFLAGS) clean
	@rm -fr Build

.DEFAULT_GOAL := build
.PHONY: format lint build test archive
