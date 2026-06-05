SDK := $(shell xcrun --sdk macosx --show-sdk-path)
MIN_MACOS := 14.0
BUILD_DIR := build
APP_NAME := Dictator-md
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
SIGN_ID := Dictator-md Stable Local
SIGN_KEYCHAIN := $(HOME)/Library/Keychains/DictatorMD-build.keychain-db

# Build universal binary (arm64 + x86_64). The Swift binary is built once per
# architecture and then merged with `lipo`. whisper.cpp's static libs are also
# built fat (see scripts/build-whisper.sh: CMAKE_OSX_ARCHITECTURES). This is
# what we ship — Apple Silicon and Intel users both need to be able to run it.

SWIFT_FILES := \
	DictatorMD/Utilities/Settings.swift \
	DictatorMD/Utilities/AppPaths.swift \
	DictatorMD/Utilities/DebugLog.swift \
	DictatorMD/Utilities/DictationMemory.swift \
	DictatorMD/Engine/WhisperBridge.swift \
	DictatorMD/Engine/AudioCapture.swift \
	DictatorMD/Engine/TextInjector.swift \
	DictatorMD/Engine/SoundFeedback.swift \
	DictatorMD/Engine/ModelManager.swift \
	DictatorMD/Engine/TextCorrector.swift \
	DictatorMD/Utilities/HotkeyMonitor.swift \
	DictatorMD/Utilities/PermissionManager.swift \
	DictatorMD/Utilities/LaunchAtLoginHelper.swift \
	DictatorMD/Utilities/AudioDeviceManager.swift \
	DictatorMD/Utilities/FocusTracker.swift \
	DictatorMD/Engine/DictationEngine.swift \
	DictatorMD/UI/MenuBarView.swift \
	DictatorMD/UI/FloatingNodeView.swift \
	DictatorMD/UI/SettingsWindowController.swift \
	DictatorMD/UI/SettingsView.swift \
	DictatorMD/UI/OnboardingView.swift \
	DictatorMD/App/DictatorMDApp.swift

LIBS := -lwhisper -lggml -lggml-base -lggml-cpu -lggml-metal -lggml-blas -lc++
FRAMEWORKS := -framework Accelerate -framework Metal -framework MetalKit -framework AVFoundation -framework CoreGraphics -framework AppKit -framework Foundation -framework ServiceManagement -framework CoreAudio

.PHONY: all clean whisper model app run dmg

all: whisper app

whisper: lib/libwhisper.a

lib/libwhisper.a:
	./scripts/build-whisper.sh

model:
	./scripts/download-model.sh small.en

define BUILD_SLICE
xcrun swiftc \
	-sdk "$(SDK)" \
	-target $(1)-apple-macos$(MIN_MACOS) \
	-import-objc-header DictatorMD/DictatorMD-Bridging-Header.h \
	-I lib -L lib \
	$(LIBS) $(FRAMEWORKS) \
	-parse-as-library \
	$(SWIFT_FILES) \
	-o $(BUILD_DIR)/DictatorMD-$(1)
endef

$(BUILD_DIR)/DictatorMD-arm64: $(SWIFT_FILES) lib/libwhisper.a
	@mkdir -p $(BUILD_DIR)
	$(call BUILD_SLICE,arm64)

$(BUILD_DIR)/DictatorMD-x86_64: $(SWIFT_FILES) lib/libwhisper.a
	@mkdir -p $(BUILD_DIR)
	$(call BUILD_SLICE,x86_64)

$(BUILD_DIR)/DictatorMD: $(BUILD_DIR)/DictatorMD-arm64 $(BUILD_DIR)/DictatorMD-x86_64
	lipo -create $^ -output $@
	@lipo -info $@

app: $(BUILD_DIR)/DictatorMD
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp $(BUILD_DIR)/DictatorMD "$(APP_BUNDLE)/Contents/MacOS/"
	@sed \
		-e 's/$$(EXECUTABLE_NAME)/DictatorMD/g' \
		-e 's/$$(PRODUCT_BUNDLE_IDENTIFIER)/com.dictatormd.DictatorMD/g' \
		-e 's/$$(PRODUCT_NAME)/$(APP_NAME)/g' \
		-e 's/$$(DEVELOPMENT_LANGUAGE)/en/g' \
		DictatorMD/Info.plist > "$(APP_BUNDLE)/Contents/Info.plist"
	@# Add LSMinimumSystemVersion (required for macOS to recognize the app)
	@/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string $(MIN_MACOS)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion $(MIN_MACOS)" "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "APPL????" > "$(APP_BUNDLE)/Contents/PkgInfo"
	@# Generate app icon
	@python3 scripts/generate-icon.py "$(APP_BUNDLE)/Contents/Resources" 2>/dev/null || true
	@# Use a stable local signing identity when available. Ad-hoc signatures
	@# change identity every rebuild, which breaks macOS Accessibility grants.
	@if [ -f "$(SIGN_KEYCHAIN)" ]; then \
		codesign --force --deep --keychain "$(SIGN_KEYCHAIN)" --sign "$(SIGN_ID)" "$(APP_BUNDLE)"; \
	else \
		codesign --force --deep --sign - "$(APP_BUNDLE)"; \
	fi
	@echo "Built $(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

dmg: app
	./scripts/create-dmg.sh

clean:
	rm -rf $(BUILD_DIR)
