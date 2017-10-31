XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

JAVASCRIPT_LIB="Stark/Resources/stark-lib.js"

STARK_SECRETS="Stark/Secrets.swift"
EXAMPLE_SECRETS="Stark/Secrets-Example.swift"

.PHONY: build clean lint concat

build:
	@xcodebuild $(XCODEFLAGS) build

clean:
	rm -fr $(JAVASCRIPT_LIB)

StarkJS/node_modules/.bin/concat:
	@cd StarkJS && npm i

StarkJS/node_modules/.bin/xo:
	@cd StarkJS && npm i

lint: StarkJS/node_modules/.bin/xo
	@cd StarkJS && npm run lint

concat: StarkJS/node_modules/.bin/concat
	@cd StarkJS && npm run build
