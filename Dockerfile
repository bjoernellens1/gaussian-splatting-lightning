FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.13_pytorch_release_2.10.0

ARG PYTORCH_ROCM_ARCH=gfx1151

ENV PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} \
    FORCE_CUDA=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=32 \
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
        wget \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN /bin/bash -lc 'for base in /opt/rocm /opt/rocm-7.2.0; do \
      if [ -d "${base}/lib/llvm" ] && [ ! -e "${base}/llvm" ]; then ln -s "${base}/lib/llvm" "${base}/llvm"; fi; \
      if [ ! -e "${base}/hip" ]; then ln -s . "${base}/hip"; fi; \
    done'

RUN wget -q https://github.com/g-truc/glm/archive/refs/tags/1.0.1.zip && \
    unzip -q 1.0.1.zip && \
    mkdir -p /usr/include && \
    rm -rf /usr/include/glm && \
    cp -r glm-1.0.1/glm /usr/include/glm

WORKDIR /build

COPY requirements/ requirements/
COPY requirements.txt .
COPY pyproject.toml .
COPY internal/ internal/
COPY utils/ utils/

COPY patch_simple_knn.sh /tmp/
COPY patch_gsplat.sh /tmp/
RUN chmod +x /tmp/patch_simple_knn.sh /tmp/patch_gsplat.sh

RUN pip install --upgrade pip setuptools wheel && \
    pip install lightning[pytorch-extra]==2.5.* pytorch-lightning==2.5.* bitsandbytes==0.45.* && \
    grep -v '^git+' requirements/common.txt > /tmp/common-no-git.txt && \
    pip install -r /tmp/common-no-git.txt && \
    /bin/bash -lc 'set -eo pipefail && \
      git clone https://github.com/yzslab/simple-knn.git /tmp/simple-knn && \
      cd /tmp/simple-knn && \
      git checkout 44f764299fa305faf6ec5ebd99939e0508331503 && \
      /tmp/patch_simple_knn.sh && \
      MAX_JOBS=32 pip install --no-build-isolation .' && \
    /bin/bash -lc 'set -eo pipefail && \
      git clone https://github.com/ROCm/gsplat.git /tmp/rocm_gsplat && \
      cd /tmp/rocm_gsplat && \
      git checkout release/1.5.3b2 && \
      /tmp/patch_gsplat.sh && \
      MAX_JOBS=32 pip install --no-build-isolation .'

COPY . /build/gaussian-splatting-lightning
WORKDIR /build/gaussian-splatting-lightning

RUN pip install --no-build-isolation .

RUN python -c "import torch; print('PyTorch', torch.__version__); print('ROCm available:', torch.cuda.is_available())"

ENTRYPOINT ["/bin/bash"]
