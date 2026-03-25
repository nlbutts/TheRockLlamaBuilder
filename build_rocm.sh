#!/bin/bash
# Download TheRock and decomp it
# Default GPU target
GPU_TARGET="gfx1201"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --gpu) GPU_TARGET="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$GPU_TARGET" == "gfx1151" ]]; then
    TARBALL="therock-dist-linux-gfx1151-7.13.0a20260325.tar.gz"
elif [[ "$GPU_TARGET" == "gfx120x" || "$GPU_TARGET" == "gfx1200" || "$GPU_TARGET" == "gfx1201" ]]; then
    TARBALL="therock-dist-linux-gfx120X-all-7.13.0a20260324.tar.gz"
else
    echo "Warning: Unknown GPU target $GPU_TARGET. Defaulting to gfx120X nightly."
    TARBALL="therock-dist-linux-gfx120X-all-7.13.0a20260324.tar.gz"
fi

echo "Pulling down $TARBALL for target $GPU_TARGET"
wget "https://therock-nightly-tarball.s3.amazonaws.com/$TARBALL"
sudo mkdir -p /opt/rocm-7.13.0
sudo tar -xzf "$TARBALL" -C /opt/rocm-7.13.0 --strip-components=1

sudo rm /opt/rocm
sudo ln -s /opt/rocm-7.13.0 /opt/rocm

# Set up the paths for the TheRock download.
export HIP_PATH=/opt/rocm
export ROCM_PATH=/opt/rocm
export HIP_PLATFORM=amd
export HIP_CLANG_PATH=/opt/rocm/llvm/bin
export HIP_INCLUDE_PATH=/opt/rocm/include
export HIP_LIB_PATH=/opt/rocm/lib
export HIP_DEVICE_LIB_PATH=/opt/rocm/lib/llvm/amdgcn/bitcode
export PATH=/opt/rocm/bin:/opt/rocm/llvm/bin:$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:/opt/rocm/llvm/lib:${LD_LIBRARY_PATH:-}
export LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:${LIBRARY_PATH:-}
export CPATH=/opt/rocm/include:${CPATH:-}
export PKG_CONFIG_PATH=/opt/rocm/lib/pkgconfig:${PKG_CONFIG_PATH:-}

# Fetch llama.cpp
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggml-org/llama.cpp.git
fi

# Build llama.cpp
cd llama.cpp
rm -rf build_rocm
mkdir -p build_rocm
cd build_rocm
cmake .. -G Ninja \
  -DCMAKE_C_COMPILER=/opt/rocm/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++ \
  -DCMAKE_CXX_FLAGS="-I/opt/rocm/include" \
  -DCMAKE_CROSSCOMPILING=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DGPU_TARGETS="$GPU_TARGET" \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DGGML_HIP=ON \
  -DGGML_OPENMP=OFF \
  -DGGML_CUDA_FORCE_CUBLAS=OFF \
  -DGGML_HIP_ROCWMMA_FATTN=ON \
  -DLLAMA_CURL=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_STATIC=OFF \
  -DCMAKE_SYSTEM_NAME=Linux

cmake --build . -j16

# Navigate to the build/bin directory
cd bin

# Copy all required ROCm libraries
echo "Copying ROCm shared libraries..."

# Copy all shared libraries from main ROCm lib directories
cp -v /opt/rocm/lib/*.so* .
cp -v /opt/rocm/lib64/*.so* .
cp -v /opt/rocm/lib/llvm/lib/*.so* .
cp -v /opt/rocm/lib/rocm_sysdeps/lib/*.so* .

# Copy the rocblas library folder
mkdir -p rocblas
cp -r /opt/rocm/lib/rocblas/library rocblas/

# Copy the hipblaslt library folder
mkdir -p hipblaslt
cp -r /opt/rocm/lib/hipblaslt/library hipblaslt/
