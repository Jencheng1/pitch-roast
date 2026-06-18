# Pickle — build + bundle a runnable macOS .app from the SwiftPM executable.
#
#   make run        build (debug), assemble Pickle.app, launch it
#   make release    build optimized, assemble + ad-hoc sign Pickle.app
#   make app        assemble the bundle from whatever was last built
#   make clean      remove build artifacts

APP        := Pickle
BUNDLE     := $(APP).app
CONFIG     ?= debug
BUILD_DIR  := .build/$(CONFIG)
CONTENTS   := $(BUNDLE)/Contents

.PHONY: run release app clean build

build:
	swift build -c $(CONFIG)

app: build
	@echo "→ assembling $(BUNDLE)"
	@rm -rf $(BUNDLE)
	@mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	@cp $(BUILD_DIR)/$(APP) $(CONTENTS)/MacOS/$(APP)
	@cp Bundle/Info.plist $(CONTENTS)/Info.plist
	@printf 'APPL????' > $(CONTENTS)/PkgInfo
	@codesign --force --sign - \
		--entitlements Bundle/$(APP).entitlements \
		--options runtime $(BUNDLE) 2>/dev/null \
		|| codesign --force --sign - --entitlements Bundle/$(APP).entitlements $(BUNDLE)
	@echo "→ built $(BUNDLE)"

run: app
	@open $(BUNDLE)

release:
	@$(MAKE) app CONFIG=release

clean:
	@rm -rf .build $(BUNDLE)
	@echo "→ cleaned"
