XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

OUTPUT_PATH="build/Stark"
ARCHIVE_PATH="$(OUTPUT_PATH)/Stark.xcarchive"

JAVASCRIPT_SOURCE=StarkLib/*.js
JAVASCRIPT_OUTPUT="Stark/Resources/stark-lib.js"

.PHONY: build bootstrap clean archive export minify

build:
	@xcodebuild $(XCODEFLAGS) build

bootstrap:
	@carthage bootstrap --platform macOS --use-submodules

clean:
	rm -fr $(OUTPUT_PATH)
	rm -fr $(JAVASCRIPT_OUTPUT)
	@xcodebuild $(XCODEFLAGS) clean

archive: clean
	@xcodebuild $(XCODEFLAGS) archive -archivePath $(ARCHIVE_PATH)

export: archive
	@xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportFormat "app" -exportPath $(OUTPUT_PATH)

node_modules/.bin/uglifyjs:
	@yarn install

minify: node_modules/.bin/uglifyjs
	node_modules/.bin/uglifyjs --compress --output $(JAVASCRIPT_OUTPUT) $(JAVASCRIPT_SOURCE)
