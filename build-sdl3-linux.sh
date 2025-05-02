#!/bin/bash
set -e

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Setup SDL3 if needed
if [ ! -d "SDL" ]; then
    source ./setup-sdl3-linux.sh
fi

# Determine host architecture
HOST_ARCH=$(uname -m)
if [ "$HOST_ARCH" = "x86_64" ]; then
    HOST_ARCH="x64"
elif [ "$HOST_ARCH" = "aarch64" ]; then
    HOST_ARCH="arm64"
fi

# Determine target architecture
TARGET_ARCH=${1:-$HOST_ARCH}
if [ "$TARGET_ARCH" != "x64" ] && [ "$TARGET_ARCH" != "arm64" ]; then
    echo "Unknown target architecture: $TARGET_ARCH"
    echo "Supported architectures: x64, arm64"
    exit 1
fi

echo "Building SDL3 for Linux $TARGET_ARCH..."

# Check for required tools
if ! command -v cmake &> /dev/null; then
    echo "CMake is required but not found."
    echo "Please install CMake: sudo apt-get update && sudo apt-get install -y cmake"
    exit 1
fi

if ! command -v ninja &> /dev/null; then
    echo "Ninja is required but not found."
    echo "Please install Ninja: sudo apt-get update && sudo apt-get install -y ninja-build"
    exit 1
fi

# Install dependencies based on TARGET_ARCH
install_dependencies() {
    echo "Installing SDL3 build dependencies..."

    # Common dependencies
    DEPS="build-essential pkg-config libasound2-dev libpulse-dev \
          libdbus-1-dev libudev-dev libibus-1.0-dev libsystemd-dev \
          libwayland-dev libxkbcommon-dev wayland-protocols \
          libx11-dev libxcursor-dev libxext-dev libxi-dev libxinerama-dev \
          libxrandr-dev libxss-dev libxt-dev libxv-dev libxxf86vm-dev \
          libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev"

    # Check if we need to install cross-compilation tools
    if [ "$TARGET_ARCH" != "$HOST_ARCH" ]; then
        if [ "$TARGET_ARCH" = "arm64" ]; then
            DEPS="$DEPS gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
        elif [ "$TARGET_ARCH" = "x64" ]; then
            DEPS="$DEPS gcc-x86-64-linux-gnu g++-x86-64-linux-gnu"
        fi
    fi

    # Install required dependencies
    sudo apt-get update
    sudo apt-get install -y $DEPS
}

# Only try to install dependencies if running as a user with sudo privileges
# and not in a CI environment where dependencies might be pre-installed
if [ -z "$CI" ] && command -v sudo &> /dev/null; then
    install_dependencies
fi

# Create output directories
mkdir -p build/linux/$TARGET_ARCH/lib
mkdir -p build/linux/$TARGET_ARCH/include/SDL3

# Clean and create build directory
BUILD_DIR=SDL/build_linux_$TARGET_ARCH
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning existing build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Set cross-compilation flags if needed
CMAKE_EXTRA_FLAGS=""
if [ "$TARGET_ARCH" != "$HOST_ARCH" ]; then
    if [ "$TARGET_ARCH" = "arm64" ]; then
        CMAKE_EXTRA_FLAGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
    elif [ "$TARGET_ARCH" = "x64" ]; then
        CMAKE_EXTRA_FLAGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 -DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++"
    fi
fi

# Run CMake to configure the build
echo "Running CMake with flags: $CMAKE_EXTRA_FLAGS"
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=ON \
    -DSDL_TEST=OFF \
    $CMAKE_EXTRA_FLAGS

if [ $? -ne 0 ]; then
    echo "CMake configuration failed with error code $?"
    exit 1
fi

# Display CMake configuration
echo ""
echo "CMAKE CONFIGURATION:"
cmake -L . | grep SDL_
echo ""

# Build
echo "Building Release configuration..."
cmake --build . --config Release

if [ $? -ne 0 ]; then
    echo "Build failed with error code $?"
    exit 1
fi

# Display build outputs
echo ""
echo "Build outputs:"
find . -name "*.so*" -type f
find . -name "*.a" -type f
echo ""

# Copy SDL files to output directory
echo "Copying binaries to output directory..."

# Copy shared libraries
echo "Searching for shared libraries..."
SHARED_LIBS_FOUND=0

# First, find the actual library files (both symlinks and real files)
echo "Looking for all SDL3 library files recursively..."
ALL_SDL_LIBS=$(find . -name "libSDL3*.so*" -type f -o -name "libSDL3*.so*" -type l)

if [ -n "$ALL_SDL_LIBS" ]; then
    echo "Found these SDL3 libraries:"
    echo "$ALL_SDL_LIBS"

    # Copy all of them to the output directory
    for lib in $ALL_SDL_LIBS; do
        echo "Copying $lib to $SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/"
        cp -av "$lib" "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/"
    done
    SHARED_LIBS_FOUND=1
else
    # Fallback to specific location checks if the recursive search didn't find anything

    # Check in current directory
    if [ -f "libSDL3.so" ] || [ -f "libSDL3.so.0" ] || [ -f "libSDL3-0.so" ]; then
        echo "Found shared library in current directory"
        find . -maxdepth 1 -name "libSDL3*.so*" \( -type f -o -type l \) -exec cp -av {} "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/" \;
        SHARED_LIBS_FOUND=1
    fi

    # Check in lib directory
    if [ -d "lib" ] && ( [ -f "lib/libSDL3.so" ] || [ -f "lib/libSDL3.so.0" ] || [ -f "lib/libSDL3-0.so" ] ); then
        echo "Found shared library in lib directory"
        find lib -name "libSDL3*.so*" \( -type f -o -type l \) -exec cp -av {} "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/" \;
        SHARED_LIBS_FOUND=1
    fi
fi

# Debug: Show what got copied
echo "Files copied to output directory:"
ls -la "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/"

# Check if we found the shared libraries
if [ $SHARED_LIBS_FOUND -eq 0 ]; then
    echo "WARNING: No libSDL3.so files found"
fi

# Copy static libraries
echo "Searching for static libraries..."
STATIC_LIB_FOUND=0

# Check in current directory
if [ -f "libSDL3.a" ]; then
    echo "Found static library in current directory"
    cp -v "libSDL3.a" "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/"
    STATIC_LIB_FOUND=1
fi

# Check in lib directory
if [ -d "lib" ] && [ -f "lib/libSDL3.a" ]; then
    echo "Found static library in lib directory"
    cp -v "lib/libSDL3.a" "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/"
    STATIC_LIB_FOUND=1
fi

# If not found in common locations, search recursively
if [ $STATIC_LIB_FOUND -eq 0 ]; then
    echo "Static library not found in common locations, searching recursively..."
    SDL_STATIC_LIB=$(find . -name "libSDL3.a" | head -1)
    if [ -n "$SDL_STATIC_LIB" ]; then
        echo "Found static library: $SDL_STATIC_LIB"
        cp -v "$SDL_STATIC_LIB" "$SCRIPT_DIR/build/linux/$TARGET_ARCH/lib/"
        STATIC_LIB_FOUND=1
    fi
fi

# Check if we found the static libraries
if [ $STATIC_LIB_FOUND -eq 0 ]; then
    echo "WARNING: libSDL3.a not found"
fi

cd "$SCRIPT_DIR"

# Copy headers
echo "Copying headers..."
# Copy the entire include directory structure recursively
cp -R SDL/include/. build/linux/$TARGET_ARCH/include/

# Create a build info file
echo "SDL3 for Linux $TARGET_ARCH" > build/linux/$TARGET_ARCH/build_info.txt
echo "Configuration: Release" >> build/linux/$TARGET_ARCH/build_info.txt
echo "Shared Library: Yes" >> build/linux/$TARGET_ARCH/build_info.txt
echo "Static Library: Yes" >> build/linux/$TARGET_ARCH/build_info.txt

# Get the current SDL3 commit hash
cd SDL
CURRENT_SDL3_COMMIT=$(git rev-parse HEAD)
echo "SDL3 Commit: $CURRENT_SDL3_COMMIT" >> ../build/linux/$TARGET_ARCH/build_info.txt
cd ..

# Create symlinks if they don't exist
# SDL typically creates symlinks like:
# libSDL3.so -> libSDL3-0.so
# libSDL3-0.so -> libSDL3-0.0.0.so
cd build/linux/$TARGET_ARCH/lib

# Find all .so files - debugging
echo "All .so files present before symlinks:"
find . -name "*.so*" | sort

# Find the primary library file (most likely the one with the most version components)
# This will find files like libSDL3.so.0.0.0 or libSDL3-0.so.0
echo "Searching for main library file..."
MAIN_LIB=""
# Look for the most specific versioned library first
for pattern in "libSDL3*.so.[0-9]*.[0-9]*.[0-9]*" "libSDL3*.so.[0-9]*.[0-9]*" "libSDL3*.so.[0-9]*" "libSDL3*.so"; do
    FOUND_LIBS=$(find . -maxdepth 1 -name "$pattern" -type f | sort -V)
    if [ -n "$FOUND_LIBS" ]; then
        # Get the highest version
        MAIN_LIB=$(echo "$FOUND_LIBS" | tail -1)
        MAIN_LIB=$(basename "$MAIN_LIB")
        echo "Found main library: $MAIN_LIB"
        break
    fi
done

# Now create the appropriate symlinks if we found a main library
if [ -n "$MAIN_LIB" ]; then
    echo "Main library file: $MAIN_LIB"

    # Different naming conventions need different handling
    if [[ "$MAIN_LIB" == *"-"* ]]; then
        # Handle format like libSDL3-0.so.0.0.0
        BASE_NAME=$(echo "$MAIN_LIB" | cut -d'.' -f1)  # gets libSDL3-0
        INTER_NAME="${BASE_NAME}.so"  # libSDL3-0.so
        ROOT_NAME=$(echo "$BASE_NAME" | sed 's/-[0-9]*$//')  # gets libSDL3
        ROOT_SO="${ROOT_NAME}.so"  # libSDL3.so

        # Create intermediate symlink if needed
        if [ ! -e "$INTER_NAME" ]; then
            echo "Creating intermediate symlink: $INTER_NAME -> $MAIN_LIB"
            ln -sf "$MAIN_LIB" "$INTER_NAME"
        fi

        # Create root symlink if needed
        if [ ! -e "$ROOT_SO" ]; then
            echo "Creating root symlink: $ROOT_SO -> $INTER_NAME"
            ln -sf "$INTER_NAME" "$ROOT_SO"
        fi
    else
        # Handle format like libSDL3.so.0.0.0
        # Extract the base name (e.g., libSDL3.so)
        BASE_NAME="${MAIN_LIB%%.*}"
        BASE_SO="${BASE_NAME}.so"

        # Extract first version component
        if [[ "$MAIN_LIB" =~ \.so\.([0-9]+) ]]; then
            FIRST_VERSION="${BASH_REMATCH[1]}"
            INTER_NAME="${BASE_NAME}.so.${FIRST_VERSION}"

            # Create intermediate symlink if needed (e.g., libSDL3.so.0 -> libSDL3.so.0.0.0)
            if [ ! -e "$INTER_NAME" ] || [ ! -L "$INTER_NAME" ]; then
                echo "Creating intermediate symlink: $INTER_NAME -> $MAIN_LIB"
                ln -sf "$MAIN_LIB" "$INTER_NAME"
            fi

            # Create base symlink if needed (e.g., libSDL3.so -> libSDL3.so.0)
            if [ ! -e "$BASE_SO" ] || [ ! -L "$BASE_SO" ]; then
                echo "Creating base symlink: $BASE_SO -> $INTER_NAME"
                ln -sf "$INTER_NAME" "$BASE_SO"
            fi
        else
            # No version number or simpler case
            if [ ! -e "$BASE_SO" ] || [ ! -L "$BASE_SO" ]; then
                echo "Creating simple symlink: $BASE_SO -> $MAIN_LIB"
                ln -sf "$MAIN_LIB" "$BASE_SO"
            fi
        fi
    fi

    # If we still don't have the basic libSDL3.so symlink, create it
    if [ ! -e "libSDL3.so" ]; then
        echo "Ensuring libSDL3.so exists by linking to the main library"
        ln -sf "$MAIN_LIB" "libSDL3.so"
    fi
elif [ -f "libSDL3.so" ] && [ ! -L "libSDL3.so" ]; then
    # If only the main .so exists and it's not a symlink, use it as our base
    MAIN_LIB="libSDL3.so"
    echo "Found non-versioned main library: $MAIN_LIB (no symlinks needed)"
else
    echo "WARNING: Could not find main library file to create symlinks"
fi

# Show final library structure
echo "Final library files and symlinks:"
find . -name "*.so*" | sort
ls -la

# Print out what we have now
echo "Final library files and symlinks:"
ls -la

cd "$SCRIPT_DIR"

# Verify files exist
echo ""
echo "Verifying output files..."
MISSING_FILES=0

# Look for any shared library
if [ -z "$(find build/linux/$TARGET_ARCH/lib -name "libSDL3*.so*" \( -type f -o -type l \))" ]; then
    echo "MISSING: build/linux/$TARGET_ARCH/lib/libSDL3.so (or similar)"
    MISSING_FILES=$((MISSING_FILES+1))
else
    echo "FOUND: $(find build/linux/$TARGET_ARCH/lib -name "libSDL3*.so*" \( -type f -o -type l \))"
fi

# Look for any static library
if [ -z "$(find build/linux/$TARGET_ARCH/lib -name "libSDL3*.a" -type f)" ]; then
    echo "MISSING: build/linux/$TARGET_ARCH/lib/libSDL3.a (or similar)"
    MISSING_FILES=$((MISSING_FILES+1))
else
    echo "FOUND: $(find build/linux/$TARGET_ARCH/lib -name "libSDL3*.a" -type f)"
fi

# Check for SDL.h in the SDL3 subdirectory
if [ ! -f "build/linux/$TARGET_ARCH/include/SDL3/SDL.h" ]; then
    echo "MISSING: build/linux/$TARGET_ARCH/include/SDL3/SDL.h"
    MISSING_FILES=$((MISSING_FILES+1))
else
    echo "FOUND: build/linux/$TARGET_ARCH/include/SDL3/SDL.h"
fi

echo ""
echo "Final directory structure:"
if [ -d "build/linux/$TARGET_ARCH/lib" ]; then
    echo "Contents of lib directory:"
    ls -la build/linux/$TARGET_ARCH/lib
else
    echo "lib directory doesn't exist"
fi

if [ -d "build/linux/$TARGET_ARCH/include" ]; then
    echo "Headers directory exists"
    find build/linux/$TARGET_ARCH/include -name "SDL.h"
else
    echo "include directory doesn't exist"
fi

if [ $MISSING_FILES -gt 0 ]; then
    echo "WARNING: $MISSING_FILES expected files are missing from the build."
else
    echo "All expected files were successfully built and copied."
fi

# Create Linux Archive with tar to preserve symlinks
echo "Creating TAR archive..."
cd build/linux/$TARGET_ARCH
tar -czvf ../../sdl3-linux-$TARGET_ARCH.tar.gz *
cd ../../..

echo ""
echo "Linux $TARGET_ARCH build complete! Libraries are available in:"
echo "  - build/linux/$TARGET_ARCH/lib/libSDL3*.so* (shared libraries with symlinks)"
echo "  - build/linux/$TARGET_ARCH/lib/libSDL3*.a (static libraries)"
echo "  - build/linux/$TARGET_ARCH/include/ (headers)"
echo "Archive created:"
echo "  - build/sdl3-linux-$TARGET_ARCH.tar.gz"