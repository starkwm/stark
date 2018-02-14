XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

BUILD_DIR=$(PWD)/Build
STARK_ACHIVE=$(BUILD_DIR)/Stark.xcarchive
EXPORT_PLIST=$(PWD)/exportPlist.plist

JAVASCRIPT_DIR=$(PWD)/StarkJS

all: build

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(STARK_ACHIVE)
	@xcodebuild -exportArchive -archivePath $(STARK_ACHIVE) -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_PLIST)

bootstrap:
	@cd $(JAVASCRIPT_DIR) && npm install

lint:
	@cd $(JAVASCRIPT_DIR) && npm run lint

concat:
	@cd $(JAVASCRIPT_DIR) && npm run build

.PHONY: all build archive bootstrap lint concat
