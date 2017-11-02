BUILDDIR=$(PWD)/Build
ARCHIVE=$(BUILDDIR)/Stark.xcarchive
EXPORT_OPTIONS=$(PWD)/exportPlist.plist

XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

JAVASCRIPT_LIB="Stark/Resources/stark-lib.js"

.PHONY: build archive lint concat

build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(ARCHIVE)
	@xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportPath $(BUILDDIR) -exportOptionsPlist $(EXPORT_OPTIONS)

StarkJS/node_modules/.bin/concat:
	@cd StarkJS && npm i

StarkJS/node_modules/.bin/xo:
	@cd StarkJS && npm i

lint: StarkJS/node_modules/.bin/xo
	@cd StarkJS && npm run lint

concat: StarkJS/node_modules/.bin/concat
	@cd StarkJS && npm run build
