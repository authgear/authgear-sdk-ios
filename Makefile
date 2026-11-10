GIT_HASH ?= git-$(shell git rev-parse --short=12 HEAD)

.PHONY: ruby-audit
ruby-audit:
	bundle exec bundler-audit check --update

# Downloads the tools pinned in tools/Makefile (swiftformat).
# .PHONY is needed because the repo has a directory named vendor.
.PHONY: vendor
vendor:
	$(MAKE) -C tools

# Run `make vendor` first.
.PHONY: format
format:
	./tools/bin/swiftformat --strict .

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

.PHONY: build-app2
build-app2:
	bundle exec fastlane example_build_app2 CURRENT_PROJECT_VERSION:$(shell date +%s)

.PHONY: upload-app2
upload-app2:
	bundle exec fastlane example_upload_app2

.PHONY: docs
docs:
	bundle exec jazzy --module Authgear --title "Authgear iOS SDK $(GIT_HASH)" --hide-documentation-coverage
