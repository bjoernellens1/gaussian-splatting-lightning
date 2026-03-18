# ──────────────────────────────────────────────────────────────────────────────
# Stage 1 – builder
#   Build all Python packages and compile ROCm C++ extensions (gfx1151).
# ──────────────────────────────────────────────────────────────────────────────
FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.13_pytorch_release_2.10.0 AS builder

# Allow the target GPU architecture to be overridden at build time:
#   docker build --build-arg PYTORCH_ROCM_ARCH=gfx1100 ...
ARG PYTORCH_ROCM_ARCH=gfx1151

# Target AMD Strix Halo / gfx1151 exclusively to keep compile time short and
# the resulting wheel small.
ENV PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} \
    # PyTorch extension builds check FORCE_CUDA=1 to trigger compilation even
    # on ROCm/HIP because the two share the same build-extension code path.
    FORCE_CUDA=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=4 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive

# System dependencies needed to compile the C++ / CUDA extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        cmake \
        ninja-build \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy only the files needed to install Python dependencies first so that
# Docker can cache this layer independently of the source code.
COPY requirements/ requirements/
COPY requirements.txt .
COPY pyproject.toml .
COPY internal/ internal/
COPY utils/ utils/

# Install Python requirements (lightning 2.5 stack – no CUDA-specific wheels
# needed here since PyTorch is already present in the base image).
RUN pip install --upgrade pip setuptools wheel && \
    pip install lightning[pytorch-extra]==2.5.* pytorch-lightning==2.5.* && \
    pip install -r requirements/common.txt

# Install gsplat (ROCm-patched fork)
RUN pip install -r requirements/gsplat.txt

# Install the gaussian-splatting-lightning package itself
COPY . /build/gaussian-splatting-lightning
WORKDIR /build/gaussian-splatting-lightning
RUN pip install --no-build-isolation -e .

ENV PYTORCH_ROCM_ARCH=gfx1151 \
    HSA_OVERRIDE_GFX_VERSION=11.5.1 \
    DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/conda/bin:$PATH"

# Runtime system libraries (OpenGL headless, libGL for cv2, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/gaussian-splatting-lightning

# Verify the installation is importable at image build time
RUN python -c "import torch; print('PyTorch', torch.__version__); \
               print('ROCm available:', torch.cuda.is_available())"

ENTRYPOINT ["/bin/bash"]
