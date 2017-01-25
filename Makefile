XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

OUTPUT_PATH="build/Stark"
ARCHIVE_PATH="$(OUTPUT_PATH)/Stark.xcarchive"

JAVASCRIPT_LIB="Stark/Resources/stark-lib.js"

STARK_SECRETS="Stark/Secrets.swift"
EXAMPLE_SECRETS="Stark/Secrets-Example.swift"

.PHONY: build bootstrap clean archive export lint minify

build:
	@xcodebuild $(XCODEFLAGS) build

bootstrap:
	@carthage bootstrap --platform macoS
	@cp $(EXAMPLE_SECRETS) $(STARK_SECRETS)
	@echo "--------------------------------------------------------------------------------"
	@echo "Created $(STARK_SECRETS). Please add your keys to it."
	@echo "--------------------------------------------------------------------------------"

clean:
	rm -fr $(OUTPUT_PATH)
	rm -fr $(JAVASCRIPT_LIB)
	@xcodebuild $(XCODEFLAGS) clean

archive: clean
	@xcodebuild $(XCODEFLAGS) archive -archivePath $(ARCHIVE_PATH)

export: archive
	@xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportFormat "app" -exportPath $(OUTPUT_PATH)

node_modules/.bin/uglifyjs:
	@yarn install

node_modules/.bin/eslint:
	@yarn install

lint: node_modules/.bin/eslint
	@yarn run lint

minify: node_modules/.bin/uglifyjs
	@yarn run minify
