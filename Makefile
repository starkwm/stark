XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

VERSION_NUMBER=$(shell agvtool what-marketing-version -terse1)
BUILD_NUMBER=$(shell agvtool what-version -terse)

.PHONY: build minify clean archive export bump-build

build:
	@xcodebuild $(XCODEFLAGS) build

node_modules/.bin/uglifyjs:
	@yarn install

minify: node_modules/.bin/uglifyjs
	node_modules/.bin/uglifyjs --compress --output Stark/Resources/stark-lib.js StarkLib/*.js

format:
	@swiftformat ./Stark

lint:
	@swiftlint lint --path ./Stark

clean:
	rm -fr build
	rm -fr Stark/Resources/stark-lib.js
	@xcodebuild $(XCODEFLAGS) clean

archive: clean
	@xcodebuild $(XCODEFLAGS) archive -archivePath "build/Stark/Stark.xcarchive"

export: archive
	@xcodebuild -exportArchive -archivePath "build/Stark/Stark.xcarchive" -exportFormat "app" -exportPath "build/Stark"
	(cd build && zip -q -r --symlinks - "Stark.app") > "build/stark-v$(VERSION_NUMBER).$(BUILD_NUMBER).zip"

bump-build:
	@agvtool next-version -all
