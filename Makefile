XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

BUILD_DIR=$(PWD)/Build
STARK_ACHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/Export.plist

JAVASCRIPT_DIR=$(PWD)/StarkJS

all: build

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ACHIVE)
	@xcodebuild -exportArchive -archivePath $(STARK_ACHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)

concat:
	@cd $(JAVASCRIPT_DIR) && cat *.js > ../Stark/Resources/stark-lib.js

.PHONY: all build archive concat
