# xcodebuild test requires a concrete device.
# -destination="generic/platform=iOS Simulator" does not work.
TEST_DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.2"
ARCHIVE_PATH ?= ./build/Release/iOS/ios_example.xcarchive
EXPORT_PATH ?= ./build/Release/iOS/ios_example.export
IPA_PATH ?= ./build/Release/iOS/ios_example.export/ios_example.ipa
# API key issuer is the Issuer you see on App Store Connect.
# It looks like a UUID.
API_ISSUER ?= "invalid"
# The filename of the API key must conform to a specific format.
# With `altool --apiKey ABC`, altool looks for the key file AuthKey_ABC.p8 in API_PRIVATE_KEYS_DIR
API_KEY ?= "invalid"

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

.PHONY: test
test:
	xcodebuild test \
		-destination $(TEST_DESTINATION) \
		-workspace Authgear.xcworkspace \
		-scheme Authgear-iOS

.PHONY: archive
archive:
	xcodebuild archive \
		-destination "generic/platform=iOS" \
		-workspace ./example/ios_example.xcworkspace \
		-scheme iOS-Example \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH)

.PHONY: exportArchive
exportArchive:
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist ./example/ExportOptions.plist \
		-exportPath $(EXPORT_PATH)

.PHONY:	validate-app
validate-app:
	xcrun altool --validate-app \
		--file $(IPA_PATH) \
		--type ios \
		--apiKey $(API_KEY) \
		--apiIssuer $(API_ISSUER)

.PHONY: upload-app
upload-app:
	xcrun altool --upload-app \
		--file $(IPA_PATH) \
		--type ios \
		--apiKey $(API_KEY) \
		--apiIssuer $(API_ISSUER)

.PHONY: docs
docs:
	bundle exec jazzy --module Authgear --title "Authgear iOS SDK $(GIT_HASH)" --hide-documentation-coverage

.PHONY: set-CFBundleVersion
set-CFBundleVersion:
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion $(shell date +%s)" ./example/ios_example/Info.plist
