#!/bin/bash
set -e

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Setup SDL3 if needed
if [ ! -d "SDL" ]; then
    source ./setup-sdl3-android.sh
fi

# Define the architectures to build for
ARCHS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")

# Define Android API level
API_LEVEL=${ANDROID_API_LEVEL:-21}
echo "Using Android API level: $API_LEVEL"

# Define NDK version from the path for reference
NDK_VERSION=$(basename "$ANDROID_NDK_HOME")
echo "Using Android NDK version: $NDK_VERSION"

# Create output directories
mkdir -p "build/android/$NDK_VERSION"

# Build for each architecture
for ARCH in "${ARCHS[@]}"; do
    echo "Building SDL3 for Android $ARCH..."

    # Create build directory
    BUILD_DIR="SDL/build_android_$ARCH"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Run CMake to configure the build
    cmake .. -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM=android-$API_LEVEL \
        -DANDROID_STL=c++_static \
        -DSDL_SHARED=OFF \
        -DSDL_STATIC=ON \
        -DSDL_TEST=OFF

    # Build
    ninja

    # Create output directory for this architecture
    OUTPUT_DIR="$SCRIPT_DIR/build/android/$NDK_VERSION/lib/$ARCH"
    mkdir -p "$OUTPUT_DIR"

    # Copy static library
    if [ -f libSDL3.a ]; then
        cp libSDL3.a "$OUTPUT_DIR"
    elif [ -f lib/libSDL3.a ]; then
        cp lib/libSDL3.a "$OUTPUT_DIR"
    else
        echo "Error: libSDL3.a not found for architecture $ARCH"
        find . -name "libSDL3.a" -type f
        exit 1
    fi

    cd "$SCRIPT_DIR"
done

# Create a combined include directory at the root
mkdir -p "build/android/$NDK_VERSION/include"
cp -R SDL/include/* "build/android/$NDK_VERSION/include/"

# Create a reference file with build information
cat > "build/android/$NDK_VERSION/build_info.txt" << EOF
SDL3 for Android
NDK Version: $NDK_VERSION
API Level: $API_LEVEL
Architectures: ${ARCHS[@]}
STL: c++_static (statically linked)
EOF

echo "Android build complete! Libraries are available in:"
echo "  - build/android/$NDK_VERSION/"
for ARCH in "${ARCHS[@]}"; do
    echo "    - $ARCH/lib/libSDL3.a (static library)"
done
echo "  - build/android/$NDK_VERSION/include/ (headers)"