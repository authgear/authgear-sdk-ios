BUILD_SDK="iphonesimulator13.2"
TEST_DESTINATION="platform=iOS Simulator,name=iPhone SE,OS=12.4"

.PHONY: format
format:
	swiftformat .

.PHONY: lint
lint:
	swiftformat -lint .

.PHONY: build
build:
	xcodebuild -quiet -workspace Authgear.xcworkspace -scheme Authgear-iOS -sdk ${BUILD_SDK} build
	xcodebuild -quiet -workspace Authgear.xcworkspace -scheme 'iOS Example' -sdk ${BUILD_SDK} build

.PHONY: test
test:
	xcodebuild -quiet -workspace Authgear.xcworkspace -scheme Authgear-iOS -destination ${TEST_DESTINATION} test

.PHONY: docs
docs:
	@command -v jazzy > /dev/null || \
	   { echo 'jazzy is required: https://github.com/realm/jazzy'; exit 1; }
	jazzy --module Authgear

.PHONY: deploy-docs
deploy-docs: docs
	./scripts/deploy_docs.sh
