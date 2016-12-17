XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

.PHONY: build minify clean

build:
	xcodebuild $(XCODEFLAGS) build

node_modules/.bin/uglifyjs:
	yarn install

minify: node_modules/.bin/uglifyjs
	node_modules/.bin/uglifyjs --compress --output Stark/Resources/stark-lib.js StarkLib/*.js

clean:
	rm -fr build
	rm -fr Stark/Resources/stark-lib.js
	xcodebuild $(XCODEFLAGS) clean

archive: clean
	xcodebuild $(XCODEFLAGS) archive -archivePath "build/Stark/Stark.xcarchive"

export: archive
	xcodebuild -exportArchive -archivePath "build/Stark/Stark.xcarchive" -exportFormat "app" -exportPath "build/Stark"
