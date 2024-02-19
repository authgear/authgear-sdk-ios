# The installed SDKs are listed here.
# Note that this also depends on the runner image.
# macos-13 is now being used.
# https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
DEVICE_SDK=iphoneos17.2
SIMULATOR_SDK=iphonesimulator17.2
TEST_DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.2"

GIT_HASH ?= git-$(shell git rev-parse --short=12 HEAD)

.PHONY: vendor
vendor:
	bundle install

.PHONY: format
format:
	swiftformat .

.PHONY: lint
lint:
	swiftformat -lint .

.PHONY: clean
clean:
	rm -rf ./build

.PHONY: framework
framework:
	xcodebuild archive -sdk $(DEVICE_SDK) -workspace Authgear.xcworkspace -scheme Authgear-iOS -configuration Release -archivePath ./build/Release/$(DEVICE_SDK)/Authgear
	xcodebuild archive -sdk $(SIMULATOR_SDK) -workspace Authgear.xcworkspace -scheme Authgear-iOS -configuration Release -archivePath ./build/Release/$(SIMULATOR_SDK)/Authgear

.PHONY: xcframework
xcframework:
	xcodebuild -create-xcframework \
		-framework ./build/Release/$(DEVICE_SDK)/Authgear.xcarchive/Products/Library/Frameworks/Authgear.framework \
		-framework ./build/Release/$(SIMULATOR_SDK)/Authgear.xcarchive/Products/Library/Frameworks/Authgear.framework \
		-output ./build/Release/Authgear.xcframework

.PHONY: build
build: framework
	xcodebuild build -sdk $(SIMULATOR_SDK) -workspace Authgear.xcworkspace -scheme 'iOS-Example'

.PHONY: test
test:
	xcodebuild -workspace Authgear.xcworkspace -scheme Authgear-iOS -destination ${TEST_DESTINATION} test

.PHONY: docs
docs:
	bundle exec jazzy --module Authgear --title "Authgear iOS SDK $(GIT_HASH)" --hide-documentation-coverage
