#!/bin/bash
set -e

# Use environment variables for commits if specified, otherwise use latest
SDL3_COMMIT=${SDL3_COMMIT:-""}

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Check for required tools
if ! command -v git &> /dev/null; then
    echo "Git is required but not found."
    exit 1
fi

# Check if ANDROID_NDK_HOME is set
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "ANDROID_NDK_HOME environment variable must be set."
    echo "Please set it to the path of your Android NDK installation."
    exit 1
fi

echo "Using Android NDK at: $ANDROID_NDK_HOME"

# Clone or update SDL3
if [ ! -d "SDL" ]; then
    echo "Cloning SDL repository..."
    git clone --depth 1 https://github.com/libsdl-org/SDL.git

    # Checkout specific commit if provided
    if [ ! -z "$SDL3_COMMIT" ]; then
        cd SDL
        git fetch --depth 1 origin $SDL3_COMMIT
        git checkout $SDL3_COMMIT
        cd ..
    fi
else
    echo "SDL directory already exists, updating..."
    cd SDL

    if [ ! -z "$SDL3_COMMIT" ]; then
        echo "Checking out specified commit: $SDL3_COMMIT"
        git fetch --depth 1 origin $SDL3_COMMIT
        git checkout $SDL3_COMMIT
    else
        echo "Using latest SDL"
        git pull
    fi
    cd ..
fi

# Store the current SDL3 commit hash for reference
cd SDL
CURRENT_SDL3_COMMIT=$(git rev-parse HEAD)
echo "Current SDL3 commit: $CURRENT_SDL3_COMMIT"
echo $CURRENT_SDL3_COMMIT > ../.sdl3_commit
cd ..

echo "SDL3 Android setup complete!"