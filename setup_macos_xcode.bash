#!/usr/bin/env bash
# ==============================================================================
# BLACKBOX Studio — Native macOS Xcode Project Generator & Builder
# Repository: https://github.com/atlaswuzhere/Black-Box-Studio-Mac
#
# Usage:
#   1. Place `setup_macos_xcode.sh` and `BlackBoxStudioApp.swift` inside your
#      cloned `Black-Box-Studio-Mac` repository root.
#   2. Run:
#        chmod +x setup_macos_xcode.sh
#        ./setup_macos_xcode.sh
#   3. It will generate `macOS-Xcode/BlackBoxStudio.xcodeproj`, bundle your web
#      engine (`index.html`, `app.js`, `style.css`, `mini.html`, `mini.js`,
#      `config.json`), and open the project directly in Xcode!
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="BlackBoxStudio"
BUNDLE_ID="com.atlaswuzhere.BlackBoxStudio"
MACOS_DIR="$ROOT_DIR/macOS-Xcode"
SRC_DIR="$MACOS_DIR/$APP_NAME"
WEBUI_DIR="$SRC_DIR/WebUI"
XCODEPROJ_DIR="$MACOS_DIR/$APP_NAME.xcodeproj"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  BLACKBOX // MACOS XCODE PROJECT GENERATOR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$SRC_DIR" "$WEBUI_DIR" "$XCODEPROJ_DIR"

# 1. Copy BlackBoxStudioApp.swift into macOS-Xcode/BlackBoxStudio/
if [[ -f "$ROOT_DIR/BlackBoxStudioApp.swift" ]]; then
    cp "$ROOT_DIR/BlackBoxStudioApp.swift" "$SRC_DIR/BlackBoxStudioApp.swift"
    echo "[✓] Copied BlackBoxStudioApp.swift -> $SRC_DIR/BlackBoxStudioApp.swift"
else
    echo "[!] BlackBoxStudioApp.swift not found in $ROOT_DIR. Please place it next to this script."
    exit 1
fi

# 2. Copy Web Engine Assets into WebUI bundle folder
WEB_FILES=("index.html" "app.js" "style.css" "mini.html" "mini.js" "config.json")
for file in "${WEB_FILES[@]}"; do
    if [[ -f "$ROOT_DIR/$file" ]]; then
        cp "$ROOT_DIR/$file" "$WEBUI_DIR/$file"
        echo "[✓] Bundled $file -> WebUI/$file"
    elif [[ -f "$ROOT_DIR/app/BLACKBOX-PERSONAL-AUDIO/$file" ]]; then
        cp "$ROOT_DIR/app/BLACKBOX-PERSONAL-AUDIO/$file" "$WEBUI_DIR/$file"
        echo "[✓] Bundled app/BLACKBOX-PERSONAL-AUDIO/$file -> WebUI/$file"
    else
        echo "[!] Warning: $file not found in repo root; make sure you run this inside Black-Box-Studio-Mac."
    fi
done

# 3. Create Info.plist
cat > "$SRC_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>BLACKBOX Studio</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>BLACKBOX Studio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>6.0.0</string>
    <key>CFBundleVersion</key>
    <string>600</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 BLACKBOX Studio (GPL-3.0)</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
echo "[✓] Created Info.plist"

# 4. Create Entitlements (Outgoing network for LRCLIB lyrics + User-Selected Read/Write File Access + Security-Scoped Bookmarks)
cat > "$SRC_DIR/$APP_NAME.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.security.assets.music.read-write</key>
    <true/>
</dict>
</plist>
EOF
echo "[✓] Created $APP_NAME.entitlements"

# 5. Create Assets.xcassets
ASSETS_DIR="$SRC_DIR/Assets.xcassets"
ICONSET_DIR="$ASSETS_DIR/AppIcon.appiconset"
mkdir -p "$ICONSET_DIR"
cat > "$ASSETS_DIR/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
cat > "$ICONSET_DIR/Contents.json" << 'EOF'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# 6. Generate BlackBoxStudio.xcodeproj/project.pbxproj
cat > "$XCODEPROJ_DIR/project.pbxproj" << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A10000012600000100000001 /* BlackBoxStudioApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = A20000012600000100000001 /* BlackBoxStudioApp.swift */; };
		A10000022600000100000001 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = A20000022600000100000001 /* Assets.xcassets */; };
		A10000032600000100000001 /* WebUI in Resources */ = {isa = PBXBuildFile; fileRef = A20000032600000100000001 /* WebUI */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A00000012600000100000001 /* BlackBoxStudio.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = BlackBoxStudio.app; sourceTree = BUILT_PRODUCTS_DIR; };
		A20000012600000100000001 /* BlackBoxStudioApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BlackBoxStudioApp.swift; sourceTree = "<group>"; };
		A20000022600000100000001 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
		A20000032600000100000001 /* WebUI */ = {isa = PBXFileReference; lastKnownFileType = folder; path = WebUI; sourceTree = "<group>"; };
		A20000042600000100000001 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		A20000052600000100000001 /* BlackBoxStudio.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = BlackBoxStudio.entitlements; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A30000012600000100000001 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A40000002600000100000001 = {
			isa = PBXGroup;
			children = (
				A40000012600000100000001 /* BlackBoxStudio */,
				A40000022600000100000001 /* Products */,
			);
			sourceTree = "<group>";
		};
		A40000012600000100000001 /* BlackBoxStudio */ = {
			isa = PBXGroup;
			children = (
				A20000012600000100000001 /* BlackBoxStudioApp.swift */,
				A20000022600000100000001 /* Assets.xcassets */,
				A20000032600000100000001 /* WebUI */,
				A20000042600000100000001 /* Info.plist */,
				A20000052600000100000001 /* BlackBoxStudio.entitlements */,
			);
			path = BlackBoxStudio;
			sourceTree = "<group>";
		};
		A40000022600000100000001 /* Products */ = {
			isa = PBXGroup;
			children = (
				A00000012600000100000001 /* BlackBoxStudio.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A50000012600000100000001 /* BlackBoxStudio */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A80000022600000100000001 /* Build configuration list for PBXNativeTarget "BlackBoxStudio" */;
			buildPhases = (
				A60000012600000100000001 /* Sources */,
				A30000012600000100000001 /* Frameworks */,
				A70000012600000100000001 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = BlackBoxStudio;
			productName = BlackBoxStudio;
			productReference = A00000012600000100000001 /* BlackBoxStudio.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A90000012600000100000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
			};
			buildConfigurationList = A80000012600000100000001 /* Build configuration list for PBXProject "BlackBoxStudio" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = A40000002600000100000001;
			productRefGroup = A40000022600000100000001 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				A50000012600000100000001 /* BlackBoxStudio */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		A70000012600000100000001 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000022600000100000001 /* Assets.xcassets in Resources */,
				A10000032600000100000001 /* WebUI in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		A60000012600000100000001 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000012600000100000001 /* BlackBoxStudioApp.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		AA0000012600000100000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 600;
				DEAD_CODE_STRIPPING = YES;
				ENABLE_HARDENED_RUNTIME = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MARKETING_VERSION = 6.0.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		AA0000022600000100000001 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 600;
				DEAD_CODE_STRIPPING = YES;
				ENABLE_HARDENED_RUNTIME = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MARKETING_VERSION = 6.0.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		AA0000032600000100000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = BlackBoxStudio/BlackBoxStudio.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				INFOPLIST_FILE = BlackBoxStudio/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.atlaswuzhere.BlackBoxStudio;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
			};
			name = Debug;
		};
		AA0000042600000100000001 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = BlackBoxStudio/BlackBoxStudio.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				INFOPLIST_FILE = BlackBoxStudio/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.atlaswuzhere.BlackBoxStudio;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A80000012600000100000001 /* Build configuration list for PBXProject "BlackBoxStudio" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA0000012600000100000001 /* Debug */,
				AA0000022600000100000001 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A80000022600000100000001 /* Build configuration list for PBXNativeTarget "BlackBoxStudio" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA0000032600000100000001 /* Debug */,
				AA0000042600000100000001 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = A90000012600000100000001 /* Project object */;
}
EOF

echo "[✓] Generated Xcode project: $XCODEPROJ_DIR"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  READY! Opening project in Xcode..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  • In Xcode, press Cmd + R to build and launch BLACKBOX Studio."
echo "  • Or build from Terminal:"
echo "      xcodebuild -project \"$XCODEPROJ_DIR\" -scheme BlackBoxStudio -configuration Release build"
echo ""

if command -v open >/dev/null 2>&1; then
    open "$XCODEPROJ_DIR" || true
fi