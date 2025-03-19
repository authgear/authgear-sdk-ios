# xcodebuild test requires a concrete device.
# -destination="generic/platform=iOS Simulator" does not work.
TEST_DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.2"

GIT_HASH ?= git-$(shell git rev-parse --short=12 HEAD)

.PHONY: format
format:
	swiftformat --strict .

.PHONY: clean
clean:
	rm -rf ./build

# It turns out SKIP_INSTALL=NO and BUILD_LIBRARY_FOR_DISTRIBUTION=YES are essential
# so that the archive contains a .framework output.
#
# We no longer use -sdk, we use -destination, as recommended by
# See https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
.PHONY: framework
framework: clean
	xcodebuild archive \
		-destination "generic/platform=iOS" \
		-workspace Authgear.xcworkspace \
		-scheme Authgear-iOS \
		-configuration Release \
		-archivePath ./build/Release/iOS/Authgear \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

	xcodebuild archive \
		-destination "generic/platform=iOS Simulator" \
		-workspace Authgear.xcworkspace \
		-scheme Authgear-iOS \
		-configuration Release \
		-archivePath ./build/Release/iOS_Simulator/Authgear \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# See https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
.PHONY: xcframework
xcframework: framework
	xcodebuild -create-xcframework \
		-archive ./build/Release/iOS/Authgear.xcarchive -framework Authgear.framework \
		-archive ./build/Release/iOS_Simulator/Authgear.xcarchive -framework Authgear.framework \
		-output ./build/Release/Authgear.xcframework

.PHONY: build
build:
	xcodebuild build \
		-destination "generic/platform=iOS" \
		-workspace Authgear.xcworkspace \
		-scheme 'iOS-Example'

.PHONY: test
test:
	xcodebuild test \
		-destination $(TEST_DESTINATION) \
		-workspace Authgear.xcworkspace \
		-scheme Authgear-iOS

.PHONY: docs
docs:
	bundle exec jazzy --module Authgear --title "Authgear iOS SDK $(GIT_HASH)" --hide-documentation-coverage
