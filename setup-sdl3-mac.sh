#!/bin/bash
set -e

# Use environment variables for commits if specified, otherwise use latest
SDL3_COMMIT=${SDL3_COMMIT:-""}

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Check if homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please install it first:"
    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install dependencies if needed
if ! command -v cmake &> /dev/null; then
    echo "Installing cmake..."
    brew install cmake
else
    echo "cmake is already installed"
fi

if ! command -v ninja &> /dev/null; then
    echo "Installing ninja..."
    brew install ninja
else
    echo "ninja is already installed"
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

echo "SDL3 setup complete!"