XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

BUILDDIR=$(PWD)/Build
ARCHIVE=$(BUILDDIR)/Stark.xcarchive
EXPORT_OPTIONS=$(PWD)/exportPlist.plist

JAVASCRIPTDIR=$(PWD)/StarkJS

build: bootstrap
	@xcodebuild $(XCODEFLAGS) build

archive: bootstrap
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(ARCHIVE)
	@xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportPath $(BUILDDIR) -exportOptionsPlist $(EXPORT_OPTIONS)

bootstrap:
	@cd $(JAVASCRIPTDIR) && npm install
	@brew install swiftlint

lint: bootstrap
	@cd $(JAVASCRIPTDIR) && npm run lint

concat: bootstrap
	@cd $(JAVASCRIPTDIR) && npm run build

.PHONY: build archive bootstrap lint concat
