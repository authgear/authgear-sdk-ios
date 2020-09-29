.PHONY: format
format:
	swiftformat .

.PHONY: lint
lint:
	swiftformat -lint .

.PHONY: build
build:
	xcodebuild -quiet -workspace Authgear.xcworkspace -scheme Authgear-iOS build

.PHONY: test
test:
	xcodebuild -quiet -workspace Authgear.xcworkspace -scheme Authgear-iOS -destination 'platform=iOS Simulator,name=iPhone SE,OS=12.4' test