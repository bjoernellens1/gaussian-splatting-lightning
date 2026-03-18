# ──────────────────────────────────────────────────────────────────────────────
# Stage 1 – builder
# ──────────────────────────────────────────────────────────────────────────────
FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.13_pytorch_release_2.10.0 AS builder

ARG PYTORCH_ROCM_ARCH=gfx1151

ENV PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} \
    FORCE_CUDA=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=4 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        cmake \
        ninja-build \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY requirements/ requirements/
COPY requirements.txt .
COPY pyproject.toml .
COPY internal/ internal/
COPY utils/ utils/

RUN pip install --upgrade pip setuptools wheel && \
    pip install lightning[pytorch-extra]==2.5.* pytorch-lightning==2.5.* && \
    pip install -r requirements/common.txt && \
    pip install -r requirements/gsplat.txt

COPY . /build/gaussian-splatting-lightning
WORKDIR /build/gaussian-splatting-lightning
RUN pip install --no-build-isolation .

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2 – runtime (FIXED)
#   Use same base image to ensure apt + conda compatibility
# ──────────────────────────────────────────────────────────────────────────────
FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.13_pytorch_release_2.10.0 AS runtime

ENV PYTORCH_ROCM_ARCH=gfx1151 \
    HSA_OVERRIDE_GFX_VERSION=11.5.1 \
    DEBIAN_FRONTEND=noninteractive

# Only runtime deps (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        git \
    && rm -rf /var/lib/apt/lists/*

# Copy Python env
COPY --from=builder /opt/conda /opt/conda

# Copy installed app
COPY --from=builder /build/gaussian-splatting-lightning /app/gaussian-splatting-lightning

ENV PATH="/opt/conda/bin:$PATH"
WORKDIR /app/gaussian-splatting-lightning

RUN python -c "import torch; print('PyTorch', torch.__version__); print('ROCm available:', torch.cuda.is_available())"

ENTRYPOINT ["/bin/bash"]
