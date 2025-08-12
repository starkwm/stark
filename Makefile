XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS"

BUILD_DIR=$(PWD)/Build
STARK_ARCHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Stark/export.plist

format:
	@swift format format -r -i Stark

lint:
	@swift format lint -r Stark

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ARCHIVE) DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
	@xcodebuild -exportArchive -archivePath $(STARK_ARCHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)
	@cp -R $(STARK_ARCHIVE)/dSYMs $(BUILD_DIR)/

clean:
	@xcodebuild $(XCODEFLAGS) clean
	@rm -fr Build

.DEFAULT_GOAL := build
.PHONY: format lint build archive
