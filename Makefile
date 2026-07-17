.PHONY: test build install clean

test:
	swift test

build:
	./scripts/build-app.sh

install: build
	./scripts/install.sh

clean:
	rm -rf .build dist
