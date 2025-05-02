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
    echo "Please install Git: sudo apt-get update && sudo apt-get install -y git"
    exit 1
fi

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

echo "SDL3 Linux setup complete!"