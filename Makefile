SRC_DIRS=Stark StarkTests
XCODEFLAGS=-project "Stark.xcodeproj" -scheme "Stark" -destination "platform=macOS,arch=arm64"

ifeq ($(GITHUB_ACTIONS),true)
TEST_SIGNING = CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
endif

format:
	@swift format format -r -i $(SRC_DIRS)

lint:
	@swift format lint --strict -r $(SRC_DIRS)

build:
	@xcodebuild $(XCODEFLAGS) build

test:
	@xcodebuild $(XCODEFLAGS) $(TEST_SIGNING) test

clean:
	@xcodebuild $(XCODEFLAGS) clean

.DEFAULT_GOAL := build
.PHONY: format lint build test clean
