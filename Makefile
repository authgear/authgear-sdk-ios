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

.PHONY: xcframework
xcframework: clean
	bundle exec fastlane sdk_xcframework

.PHONY: test
test:
	bundle exec fastlane sdk_test

.PHONY: pod-install
pod-install:
	cd ./example; bundle exec pod install

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
