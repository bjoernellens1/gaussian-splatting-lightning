FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.13_pytorch_release_2.10.0

ARG PYTORCH_ROCM_ARCH=gfx1151

ENV PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} \
    FORCE_CUDA=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=4 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive \
    HSA_OVERRIDE_GFX_VERSION=11.5.1

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        cmake \
        ninja-build \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY requirements/ requirements/
COPY requirements.txt .
COPY pyproject.toml .
COPY internal/ internal/
COPY utils/ utils/

RUN pip install --upgrade pip setuptools wheel && \
    pip install lightning[pytorch-extra]==2.5.* pytorch-lightning==2.5.* && \
    pip install -r requirements.txt && \
    pip install --no-build-isolation \
        git+https://github.com/graphdeco-inria/diff-gaussian-rasterization.git@59f5f77e3ddbac3ed9db93ec2cfe99ed6c5d121d && \
    pip install --no-build-isolation \
        git+https://github.com/yzslab/simple-knn.git@44f764299fa305faf6ec5ebd99939e0508331503 && \
    pip install --no-build-isolation -r requirements/gsplat.txt

COPY . /build/gaussian-splatting-lightning
WORKDIR /build/gaussian-splatting-lightning

RUN pip install --no-build-isolation .

RUN python -c "import torch; print('PyTorch', torch.__version__); print('ROCm available:', torch.cuda.is_available())"

ENTRYPOINT ["/bin/bash"]
