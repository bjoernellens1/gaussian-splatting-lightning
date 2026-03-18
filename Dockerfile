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

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2 – runtime
#   Ubuntu 24.04 base with ROCm 7.2 runtime; copy the Python environment and
#   the installed application from the builder stage.
# ──────────────────────────────────────────────────────────────────────────────
FROM ubuntu:24.04 AS runtime

# Override at build time if needed:
#   docker build --build-arg ROCM_VERSION=7.2 --build-arg UBUNTU_CODENAME=noble ...
ARG ROCM_VERSION=7.2
ARG UBUNTU_CODENAME=noble

ENV PYTORCH_ROCM_ARCH=gfx1151 \
    HSA_OVERRIDE_GFX_VERSION=11.5.1 \
    DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/conda/bin:$PATH"

# Install ROCm from AMD's TheRock/official repository and runtime system libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        ca-certificates \
    && wget -qO /tmp/rocm.gpg.key https://repo.radeon.com/rocm/rocm.gpg.key \
    && install -D -m 644 /tmp/rocm.gpg.key /etc/apt/keyrings/rocm.gpg \
    && rm /tmp/rocm.gpg.key \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${UBUNTU_CODENAME} main" \
       > /etc/apt/sources.list.d/rocm.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        rocm-hip-runtime \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        git \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire conda/Python environment from the builder stage
COPY --from=builder /opt/conda /opt/conda

# Copy installed application source (editable install keeps the .pth file)
COPY --from=builder /build/gaussian-splatting-lightning /app/gaussian-splatting-lightning

WORKDIR /app/gaussian-splatting-lightning

# Verify the installation is importable at image build time
RUN python -c "import torch; print('PyTorch', torch.__version__); \
               print('ROCm available:', torch.cuda.is_available())"

ENTRYPOINT ["/bin/bash"]
