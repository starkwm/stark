XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

BUILD_DIR=$(PWD)/Build
STARK_ACHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Export.plist

all: build

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ACHIVE)
	@xcodebuild -exportArchive -archivePath $(STARK_ACHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)

.PHONY: all build archive
