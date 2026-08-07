.PHONY: build run clean test

build:
	./build.sh

run: build
	@pkill -x Tessel 2>/dev/null || true
	open build/Tessel.app

test:
	swift test

clean:
	rm -rf .build build
