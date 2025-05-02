#!/bin/bash
set -e

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Setup SDL3 if needed
if [ ! -d "SDL" ]; then
    source ./setup-sdl3-mac.sh
fi

# Create build directories
mkdir -p build/mac/arm64
mkdir -p build/mac/x86_64
mkdir -p build/mac/universal/lib
mkdir -p build/mac/universal/include

# Build for macOS ARM64
echo "Building SDL3 for macOS ARM64..."
cd "$SCRIPT_DIR"
mkdir -p SDL/build_arm64
cd SDL/build_arm64
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF
ninja

# Copy the dylibs to build directory
cp -R *.dylib "$SCRIPT_DIR/build/mac/arm64/"

# Build for macOS x86_64
echo "Building SDL3 for macOS x86_64..."
cd "$SCRIPT_DIR"
mkdir -p SDL/build_x86_64
cd SDL/build_x86_64
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF
ninja

# Copy the dylibs to build directory
cp -R *.dylib "$SCRIPT_DIR/build/mac/x86_64/"

# Create universal binaries
cd "$SCRIPT_DIR"
echo "Creating universal binaries..."

# Get a list of all dylibs from the arm64 build
DYLIBS=$(ls build/mac/arm64/)

# For each dylib, create a universal version
for DYLIB in $DYLIBS; do
    if [[ $DYLIB == *.dylib ]]; then
        echo "Creating universal binary for $DYLIB..."

        # Create universal binary
        lipo -create -output "build/mac/universal/lib/$DYLIB" \
            "build/mac/arm64/$DYLIB" \
            "build/mac/x86_64/$DYLIB"

        # Fix install name if needed
        install_name_tool -id "@rpath/$DYLIB" "build/mac/universal/lib/$DYLIB"
    fi
done

# Copy headers
echo "Copying headers..."
cp -R SDL/include/* build/mac/universal/include/

echo "macOS build complete! Libraries are available in:"
echo "  - build/mac/arm64/ (for Apple Silicon Macs)"
echo "  - build/mac/x86_64/ (for Intel Macs)"
echo "  - build/mac/universal/lib/ (Universal binaries for both architectures)"
echo "Headers are included in build/mac/universal/include/"