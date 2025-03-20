# API key issuer is the Issuer you see on App Store Connect.
# It looks like a UUID.
API_ISSUER ?= "invalid"
# The filename of the API key must conform to a specific format.
# With `altool --apiKey ABC`, altool looks for the key file AuthKey_ABC.p8 in API_PRIVATE_KEYS_DIR
API_KEY ?= "invalid"
API_KEY_PATH ?= ./AuthKey_invalid.p8

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

.PHONY: build-app
build-app:
	bundle exec fastlane example_build_app

.PHONY: fastlane-api-key-json
fastlane-api-key-json:
	jq --slurp --raw-input > ./build/fastlane-api-key.json \
		--arg key_id $(API_KEY) \
		--arg issuer_id $(API_ISSUER) \
		'{key_id: $$key_id, issuer_id: $$issuer_id, key: .}' \
		$(API_KEY_PATH)

.PHONY: upload-app
upload-app:
	bundle exec fastlane example_upload_app

.PHONY: docs
docs:
	bundle exec jazzy --module Authgear --title "Authgear iOS SDK $(GIT_HASH)" --hide-documentation-coverage

.PHONY: set-CFBundleVersion
set-CFBundleVersion:
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion $(shell date +%s)" ./example/ios_example/Info.plist
