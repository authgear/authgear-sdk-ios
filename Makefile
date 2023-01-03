DEVICE_SDK=iphoneos15.2
SIMULATOR_SDK=iphonesimulator15.2
TEST_DESTINATION="platform=iOS Simulator,name=iPhone 13,OS=15.2"

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
	bundle exec jazzy --module Authgear

.PHONY: deploy-docs
deploy-docs: docs
	./scripts/deploy_docs.sh
