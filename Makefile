.PHONY: all build test test-ui run verify-lifecycle clean package release-local unregister-all help list lint

all: build

build:
	xcodegen generate
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
		build -project CopyPath.xcodeproj -scheme CopyPath \
		-destination 'platform=macOS' -derivedDataPath DerivedData

test:
	xcodegen generate
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
		test -project CopyPath.xcodeproj -scheme CopyPathUnitTests \
		-destination 'platform=macOS' -derivedDataPath DerivedData

test-ui:
	xcodegen generate
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
		test -project CopyPath.xcodeproj -scheme CopyPath \
		-destination 'platform=macOS' -derivedDataPath DerivedData

run:
	./scripts/build_and_run.sh run

verify-lifecycle:
	./scripts/verify_lifecycle.sh

clean:
	rm -rf DerivedData CopyPath.xcodeproj build

package:
	./scripts/package.sh

release-local:
	./scripts/release_local_signed.sh --publish

unregister-all:
	@echo "🧹 Unregistering all versions of Copy Path Finder extension..."
	-pluginkit -r /Applications/CopyPathAs.app/Contents/PlugIns/CopyPathFinderExtension.appex 2>/dev/null
	-pluginkit -r ~/Applications/CopyPathAs.app/Contents/PlugIns/CopyPathFinderExtension.appex 2>/dev/null
	-pluginkit -r /Applications/CopyPath.app/Contents/PlugIns/CopyPathFinderExtension.appex 2>/dev/null
	-pluginkit -r ~/Applications/CopyPath.app/Contents/PlugIns/CopyPathFinderExtension.appex 2>/dev/null
	-killall Finder 2>/dev/null
	@echo "✅ All versions unregistered. Finder restarted."

lint:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint --no-cache

help:
	@echo "Available commands:"
	@echo "  make build             - Generate Xcode project and build the debug app"
	@echo "  make test              - Run the unit tests"
	@echo "  make test-ui           - Run the UI tests"
	@echo "  make lint              - Lint the Swift source code"
	@echo "  make run               - Build and run the app locally"
	@echo "  make verify-lifecycle  - Run the lifecycle verification suite"
	@echo "  make clean             - Remove all build and generated files"
	@echo "  make package           - Package the app into a Release ZIP and DMG"
	@echo "  make release-local     - Sign, notarize, package, and publish a maintainer release"
	@echo "  make unregister-all    - Unregister all extensions and restart Finder"
	@echo "  make help (or make list) - Display this list of options"

list: help
