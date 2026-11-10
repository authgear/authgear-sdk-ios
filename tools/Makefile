# Tools used by this repo, pinned so that local and CI results are identical.
# `make` downloads them into ./bin.
#
# To upgrade swiftformat, change the version and the sha256 of swiftformat.zip
# shown on https://github.com/nicklockwood/SwiftFormat/releases

SWIFTFORMAT_VERSION := 0.63.0
SWIFTFORMAT_SHA256 := 28c7802e11fa5ae113d903066439c6bb1be20a8ac1ad9709c42616a7e273fb0f

.PHONY: all
all: bin/swiftformat

# Depends on this Makefile so that changing the version downloads it again.
bin/swiftformat: Makefile
	rm -rf bin/swiftformat bin/swiftformat.zip
	mkdir -p bin
	curl -fsSL -o bin/swiftformat.zip https://github.com/nicklockwood/SwiftFormat/releases/download/$(SWIFTFORMAT_VERSION)/swiftformat.zip
	echo "$(SWIFTFORMAT_SHA256)  bin/swiftformat.zip" | shasum -a 256 -c -
	unzip -oq bin/swiftformat.zip -d bin
	chmod +x bin/swiftformat
	touch bin/swiftformat
	rm bin/swiftformat.zip
