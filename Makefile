SRC_DIRS=Stark StarkTests
XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS,arch=arm64"

format:
	@swift format format -r -i $(SRC_DIRS)

lint:
	@swift format lint -r $(SRC_DIRS)

build:
	@xcodebuild $(XCODEFLAGS) build

test:
	@xcodebuild $(XCODEFLAGS) test

clean:
	@xcodebuild $(XCODEFLAGS) clean

.DEFAULT_GOAL := build
.PHONY: format lint build test clean
