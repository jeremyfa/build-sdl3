#!/bin/bash
set -e

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Check for iOS toolchain file
if [ ! -f "ios.toolchain.cmake" ]; then
    echo "iOS toolchain file not found. Downloading from github..."
    curl -L -o ios.toolchain.cmake https://raw.githubusercontent.com/leetal/ios-cmake/master/ios.toolchain.cmake
    if [ $? -ne 0 ]; then
        echo "Failed to download iOS toolchain file."
        exit 1
    fi
    echo "Downloaded iOS toolchain file."
fi

# Setup SDL3 if needed
if [ ! -d "SDL" ]; then
    source ./setup-sdl3-mac.sh
fi

# Create output directories
mkdir -p build/ios/arm64
mkdir -p build/ios/simulator-arm64
mkdir -p build/ios/simulator-x86_64
mkdir -p build/ios/simulator-combined
mkdir -p build/ios/universal

# Build for iOS device (arm64)
echo "Building SDL3 for iOS (arm64)..."
cd "$SCRIPT_DIR"
mkdir -p SDL/build_ios_arm64
cd SDL/build_ios_arm64
cmake .. -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=../../ios.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DPLATFORM=OS64 \
    -DENABLE_BITCODE=OFF \
    -DENABLE_ARC=ON \
    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
    -DDEPLOYMENT_TARGET=16.0 \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF
ninja

# Create a framework for the device build
mkdir -p "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Headers/SDL3"
mkdir -p "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Modules"

# Look for the dynamic library in both the current directory and a potential lib/ subdirectory
if [ -f libSDL3.dylib ] || [ -f libSDL3.0.dylib ]; then
    # Copy the main library file
    if [ -f libSDL3.0.dylib ]; then
        cp libSDL3.0.dylib "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/SDL3"
    else
        cp libSDL3.dylib "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/SDL3"
    fi
elif [ -f lib/libSDL3.dylib ] || [ -f lib/libSDL3.0.dylib ]; then
    # Copy from lib/ directory
    if [ -f lib/libSDL3.0.dylib ]; then
        cp lib/libSDL3.0.dylib "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/SDL3"
    else
        cp lib/libSDL3.dylib "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/SDL3"
    fi
else
    echo "Error: SDL3 dynamic library not found in expected locations"
    find . -name "libSDL3*.dylib" -type f
    exit 1
fi

# Copy and organize headers within the framework
cp -R ../include/* "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Headers/"

# Create a module map file for the framework
cat > "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Modules/module.modulemap" << EOL
framework module SDL3 {
  umbrella header "SDL3/SDL.h"
  export *
  module * { export * }
}
EOL
cp -R ../include/* "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Headers/"
cat > "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>SDL3</string>
    <key>CFBundleIdentifier</key>
    <string>org.libsdl.SDL3</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SDL3</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

# Build for iOS Simulator (arm64)
echo "Building SDL3 for iOS Simulator (arm64)..."
cd "$SCRIPT_DIR"
mkdir -p SDL/build_ios_simulator_arm64
cd SDL/build_ios_simulator_arm64
cmake .. -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=../../ios.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DPLATFORM=SIMULATORARM64 \
    -DENABLE_BITCODE=OFF \
    -DENABLE_ARC=ON \
    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
    -DDEPLOYMENT_TARGET=16.0 \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF
ninja

# Create a framework for the simulator arm64 build
mkdir -p "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Headers"
mkdir -p "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Modules"

# Look for the dynamic library in both the current directory and a potential lib/ subdirectory
if [ -f libSDL3.dylib ] || [ -f libSDL3.0.dylib ]; then
    # Copy the main library file
    if [ -f libSDL3.0.dylib ]; then
        cp libSDL3.0.dylib "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/SDL3"
    else
        cp libSDL3.dylib "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/SDL3"
    fi
elif [ -f lib/libSDL3.dylib ] || [ -f lib/libSDL3.0.dylib ]; then
    # Copy from lib/ directory
    if [ -f lib/libSDL3.0.dylib ]; then
        cp lib/libSDL3.0.dylib "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/SDL3"
    else
        cp lib/libSDL3.dylib "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/SDL3"
    fi
else
    echo "Error: SDL3 dynamic library not found in expected locations"
    find . -name "libSDL3*.dylib" -type f
    exit 1
fi

# Copy and organize headers within the framework
cp -R ../include/* "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Headers/"

# Create a module map file for the framework
cp "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Modules/module.modulemap" "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Modules/"
cp -R ../include/* "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Headers/"
cp "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Info.plist" "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Info.plist"

# Build for iOS Simulator (x86_64)
echo "Building SDL3 for iOS Simulator (x86_64)..."
cd "$SCRIPT_DIR"
mkdir -p SDL/build_ios_simulator_x86_64
cd SDL/build_ios_simulator_x86_64
cmake .. -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=../../ios.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DPLATFORM=SIMULATOR64 \
    -DENABLE_BITCODE=OFF \
    -DENABLE_ARC=ON \
    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
    -DDEPLOYMENT_TARGET=16.0 \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF
ninja

# Create a framework for the simulator x86_64 build
mkdir -p "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/Headers"
mkdir -p "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/Modules"

# Look for the dynamic library in both the current directory and a potential lib/ subdirectory
if [ -f libSDL3.dylib ] || [ -f libSDL3.0.dylib ]; then
    # Copy the main library file
    if [ -f libSDL3.0.dylib ]; then
        cp libSDL3.0.dylib "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/SDL3"
    else
        cp libSDL3.dylib "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/SDL3"
    fi
elif [ -f lib/libSDL3.dylib ] || [ -f lib/libSDL3.0.dylib ]; then
    # Copy from lib/ directory
    if [ -f lib/libSDL3.0.dylib ]; then
        cp lib/libSDL3.0.dylib "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/SDL3"
    else
        cp lib/libSDL3.dylib "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/SDL3"
    fi
else
    echo "Error: SDL3 dynamic library not found in expected locations"
    find . -name "libSDL3*.dylib" -type f
    exit 1
fi

# Copy and organize headers within the framework
cp -R ../include/* "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/Headers/"

# Create a module map file for the framework
cp "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Modules/module.modulemap" "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/Modules/"
cp -R ../include/* "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/Headers/"
cp "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Info.plist" "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/Info.plist"

# Create a combined simulator framework
echo "Creating combined simulator framework..."
mkdir -p "$SCRIPT_DIR/build/ios/simulator-combined/SDL3.framework/Headers"
mkdir -p "$SCRIPT_DIR/build/ios/simulator-combined/SDL3.framework/Modules"

# Copy headers and modulemap
cp -R "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/Headers/" "$SCRIPT_DIR/build/ios/simulator-combined/SDL3.framework/Headers/"
cp "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Modules/module.modulemap" "$SCRIPT_DIR/build/ios/simulator-combined/SDL3.framework/Modules/"
cp "$SCRIPT_DIR/build/ios/arm64/SDL3.framework/Info.plist" "$SCRIPT_DIR/build/ios/simulator-combined/SDL3.framework/Info.plist"

# Create a universal binary for the simulator
lipo -create \
    "$SCRIPT_DIR/build/ios/simulator-arm64/SDL3.framework/SDL3" \
    "$SCRIPT_DIR/build/ios/simulator-x86_64/SDL3.framework/SDL3" \
    -output "$SCRIPT_DIR/build/ios/simulator-combined/SDL3.framework/SDL3"

# Create XCFramework
echo "Creating XCFramework..."
cd "$SCRIPT_DIR"
xcodebuild -create-xcframework \
    -framework "build/ios/arm64/SDL3.framework" \
    -framework "build/ios/simulator-combined/SDL3.framework" \
    -output "build/ios/universal/SDL3.xcframework"

# Create a standard include directory structure alongside the XCFramework
echo "Creating standard include directory structure..."
mkdir -p "build/ios/universal/include"

# Copy headers to the standard include structure
cp -R SDL/include/* "build/ios/universal/include/"

# Create a README in the include directory explaining usage
cat > "build/ios/universal/include/README.md" << EOL
# SDL3 Headers for iOS

These headers are organized in a standard structure for cross-platform consistency.

## Usage in Cross-Platform Code

For cross-platform code that needs to compile on multiple platforms (Windows, macOS, iOS, Android),
include these headers as follows:

\`\`\`c
#include <SDL.h>
\`\`\`

## Integration with Xcode

1. Add this include directory to your Header Search Paths
2. Link against the SDL3 XCFramework

## Alternative Usage for iOS-only Code

For iOS-only code, you can also use the framework-style includes:

\`\`\`objc
#import <SDL3/SDL.h>
\`\`\`

Both approaches will work, but the first is recommended for cross-platform consistency.
EOL

echo "iOS build complete! Frameworks are available in:"
echo "  - build/ios/arm64/SDL3.framework (for iOS devices)"
echo "  - build/ios/simulator-arm64/SDL3.framework (for ARM64 simulators)"
echo "  - build/ios/simulator-x86_64/SDL3.framework (for x86_64 simulators)"
echo "  - build/ios/simulator-combined/SDL3.framework (combined simulators with both arm64 and x86_64)"
echo "  - build/ios/universal/SDL3.xcframework (XCFramework for all platforms)"