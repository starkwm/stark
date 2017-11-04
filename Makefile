XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

BUILDDIR=$(PWD)/Build
ARCHIVE=$(BUILDDIR)/Stark.xcarchive
EXPORT_OPTIONS=$(PWD)/exportPlist.plist


build:
	@xcodebuild $(XCODEFLAGS) build

archive:
	@xcodebuild $(XCODEFLAGS) clean archive -archivePath $(ARCHIVE)
	@xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportPath $(BUILDDIR) -exportOptionsPlist $(EXPORT_OPTIONS)

bootstrap:
	@cd StarkJS && npm install
	@brew install swiftlint

lint: bootstrap
	@cd StarkJS && npm run lint

concat: bootstrap
	@cd StarkJS && npm run build

.PHONY: build archive bootstrap lint concat
