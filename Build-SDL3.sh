#!/bin/bash
# Pulsar4X Native Deps Builder
# Run this script whenever you want to update SDL3 + siblings.
# Builds everything against the Steam Runtime (sniper) for best Linux compatibility.

set -euo pipefail

# ================== CONFIGURATION ==================
# ←←← Update these when you want to bump versions ←←←
SDL_TAG="release-3.2.8"           # Change to the SDL3 version you want (e.g. release-3.4.0)
SDL_IMAGE_TAG="prerelease-3.2.0"  # Usually tracks SDL3 version closely
SDL_TTF_TAG="release-3.2.2"       # Current stable as of early 2026
SDL3_CS_BRANCH="main"             # SDL3-CS has no real tags → use main or a specific commit hash

BUILD_DIR="$(pwd)/build-dir"
OUTPUT_DIR="$(pwd)/output"

IMAGE="registry.gitlab.steamos.cloud/steamrt/sniper/sdk:latest"
# ===================================================

echo "=== Starting build in Steam Runtime SDK ==="

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# Pull the latest SDK image
docker pull "$IMAGE"

docker run --rm \
  -v "$BUILD_DIR:/work" \
  -v "$OUTPUT_DIR:/output" \
  "$IMAGE" /bin/bash -c "
    set -euo pipefail

    apt update
    apt install -y build-essential cmake git pkg-config wget \
      libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev \
      libx11-dev libxi-dev libxrandr-dev libxinerama-dev \
      libxcursor-dev libxext-dev libwayland-dev libxkbcommon-dev \
      libjpeg-dev libpng-dev libwebp-dev libtiff-dev \
      libfreetype6-dev libharfbuzz-dev

    # Install .NET 8 SDK
    wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    apt update
    apt install -y dotnet-sdk-8.0

    cd /work

    echo '=== Building SDL3 ==='
    rm -rf SDL
    git clone --depth 1 --branch $SDL_TAG https://github.com/libsdl-org/SDL.git
    cd SDL
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON
    make -j\$(nproc)
    cp libSDL3.so* /output/

    export PKG_CONFIG_PATH=/work/SDL/build:\$PKG_CONFIG_PATH

    echo '=== Building SDL_image ==='
    cd /work
    rm -rf SDL_image
    git clone --depth 1 --branch $SDL_IMAGE_TAG https://github.com/libsdl-org/SDL_image.git
    cd SDL_image
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON
    make -j\$(nproc)
    cp libSDL3_image.so* /output/

    echo '=== Building SDL_ttf ==='
    cd /work
    rm -rf SDL_ttf
    git clone --depth 1 --branch $SDL_TTF_TAG https://github.com/libsdl-org/SDL_ttf.git
    cd SDL_ttf
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON
    make -j\$(nproc)
    cp libSDL3_ttf.so* /output/

    echo '=== Building SDL3-CS .dll ==='
    cd /work
    rm -rf SDL3-CS
    git clone --depth 1 --branch $SDL3_CS_BRANCH https://github.com/edwardgushchin/SDL3-CS.git
    cd SDL3-CS
    dotnet build -c Release --no-self-contained
    cp SDL3-CS/bin/Release/net8.0/SDL3-CS.dll /output/

    echo '=== All builds finished successfully ==='
  "

echo "✅ Build complete!"
echo "   Output files are in: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "   1. Copy the contents of output/ into Pulsar4X.Client/Libs/linux-x64/"
echo "   2. Commit the updated .so + .dll files in the main project"
echo "   3. (Optional) Update the version comments at the top of this script"
