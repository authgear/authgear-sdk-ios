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
	bundle exec fastlane example_build_app CURRENT_PROJECT_VERSION:$(shell date +%s)

.PHONY: upload-app
upload-app:
	bundle exec fastlane example_upload_app

.PHONY: docs
docs:
	bundle exec jazzy --module Authgear --title "Authgear iOS SDK $(GIT_HASH)" --hide-documentation-coverage
