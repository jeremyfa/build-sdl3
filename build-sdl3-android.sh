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
mkdir -p "build/android/lib"
mkdir -p "build/android/jniLibs"
mkdir -p "build/android/include"

# Build for each architecture
for ARCH in "${ARCHS[@]}"; do
    echo "Building SDL3 for Android $ARCH..."

    # Create build directory for static library
    STATIC_BUILD_DIR="SDL/build_android_static_$ARCH"
    mkdir -p "$STATIC_BUILD_DIR"
    cd "$STATIC_BUILD_DIR"

    # Run CMake to configure the build for static library
    cmake .. -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM=android-$API_LEVEL \
        -DANDROID_STL=c++_static \
        -DSDL_SHARED=OFF \
        -DSDL_STATIC=ON \
        -DSDL_TEST=OFF

    # Build static library
    ninja

    # Create output directory for this architecture
    OUTPUT_DIR="$SCRIPT_DIR/build/android/lib/$ARCH"
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

    # Now build shared library
    SHARED_BUILD_DIR="SDL/build_android_shared_$ARCH"
    mkdir -p "$SHARED_BUILD_DIR"
    cd "$SHARED_BUILD_DIR"

    # Run CMake to configure the build for shared library
    cmake .. -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM=android-$API_LEVEL \
        -DANDROID_STL=c++_static \
        -DSDL_SHARED=ON \
        -DSDL_STATIC=OFF \
        -DSDL_TEST=OFF

    # Build shared library
    ninja

    # Create jniLibs directory for this architecture
    JNILIBS_DIR="$SCRIPT_DIR/build/android/jniLibs/$ARCH"
    mkdir -p "$JNILIBS_DIR"

    # Copy shared library
    if [ -f libSDL3.so ]; then
        cp libSDL3.so "$JNILIBS_DIR"
    elif [ -f lib/libSDL3.so ]; then
        cp lib/libSDL3.so "$JNILIBS_DIR"
    else
        echo "Error: libSDL3.so not found for architecture $ARCH"
        find . -name "libSDL3.so" -type f
        exit 1
    fi

    cd "$SCRIPT_DIR"
done

# Copy include directory
cp -R SDL/include/* "build/android/include/"

# Create a reference file with build information
cat > "build/android/build_info.txt" << EOF
SDL3 for Android
NDK Version: $NDK_VERSION
API Level: $API_LEVEL
Architectures: ${ARCHS[@]}
Static Library: YES (with c++_static STL)
Shared Library: YES (with c++_static STL)
EOF

# Get the current SDL3 commit hash
cd SDL
CURRENT_SDL3_COMMIT=$(git rev-parse HEAD)
echo "SDL3 Commit: $CURRENT_SDL3_COMMIT" >> ../build/android/build_info.txt
cd ..

echo "Android build complete! Libraries are available in:"
echo "  - build/android/lib/ (static libraries)"
echo "  - build/android/jniLibs/ (shared libraries)"
echo "  - build/android/include/ (headers)"