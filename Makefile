XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark"

JAVASCRIPT_LIB="Stark/Resources/stark-lib.js"

STARK_SECRETS="Stark/Secrets.swift"
EXAMPLE_SECRETS="Stark/Secrets-Example.swift"

.PHONY: build bootstrap clean lint concat

build:
	@xcodebuild $(XCODEFLAGS) build

clean:
	rm -fr $(JAVASCRIPT_LIB)

node_modules/.bin/concat:
	@yarn install

node_modules/.bin/xo:
	@yarn install

lint: node_modules/.bin/xo
	@yarn lint

concat: node_modules/.bin/concat
	@yarn build
