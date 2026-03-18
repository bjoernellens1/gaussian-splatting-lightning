# Docker / Podman Quick-Start

This guide explains how to build and run **gaussian-splatting-lightning** inside
a portable container with full AMD ROCm GPU access on **gfx1151** hardware
(AMD Strix Halo / Ryzen AI 300 series).

---

## Image layout (multi-stage build)

| Stage | Base image | Purpose |
|-------|-----------|---------|
| `builder` | `rocm/pytorch:rocm7.2_ubuntu24.04_py3.13_pytorch_release_2.10.0` | Compile all Python packages and ROCm C++ extensions (`PYTORCH_ROCM_ARCH=gfx1151`) |
| `runtime` | `kyuz0/amd-strix-halo-toolboxes:rocm-7.2` | Lean final image optimised for AMD Strix Halo; receives the compiled environment from the builder stage |

---

## 1. Pull the pre-built image

```bash
docker pull ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest
# or with Podman
podman pull ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest
```

---

## 2. Build locally

```bash
# Docker
docker build -t gspl:local .

# Podman
podman build -t gspl:local .
```

To target a different ROCm architecture, pass the build-arg:

```bash
docker build --build-arg PYTORCH_ROCM_ARCH=gfx1100 -t gspl:gfx1100 .
```

---

## 3. Run with GPU access

### 3a. Using the launch script (recommended)

The included `run.sh` automatically detects Docker or Podman and sets all
required GPU device flags:

```bash
chmod +x run.sh

# Interactive shell
./run.sh

# Run a specific command directly
./run.sh python main.py fit --config configs/colmap.yaml

# Override the image name
IMAGE=gspl:local ./run.sh
```

### 3b. Manual `docker run`

```bash
docker run --rm -it \
  --device /dev/dri \
  --device /dev/kfd \
  --group-add video \
  --group-add render \
  --group-add sudo \          # needed on some distros for HSA init; remove if not required
  --security-opt seccomp=unconfined \
  --workdir /app/gaussian-splatting-lightning \
  ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest
```

### 3c. Manual `podman run`

Podman rootless mode additionally requires `--userns=keep-id` so that
volume-mounted files remain accessible under your regular user:

```bash
podman run --rm -it \
  --device /dev/dri \
  --device /dev/kfd \
  --group-add video \
  --group-add render \
  --group-add sudo \          # needed on some distros for HSA init; remove if not required
  --security-opt seccomp=unconfined \
  --userns=keep-id \
  --workdir /app/gaussian-splatting-lightning \
  ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest
```

---

## 4. Mount your dataset

Pass a host directory into the container with `-v` / `--volume`.
The `:z` suffix re-labels the SELinux context so Podman can write to it:

```bash
# Docker
docker run --rm -it \
  --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render --group-add sudo \
  --security-opt seccomp=unconfined \
  --volume /path/to/your/data:/data:z \
  --workdir /app/gaussian-splatting-lightning \
  ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest \
  python main.py fit --config configs/colmap.yaml \
    data.parser.data_path=/data/my_scene
```

Or set `DATA_DIR` before running the script:

```bash
DATA_DIR=/path/to/your/data ./run.sh \
  python main.py fit --config configs/colmap.yaml \
    data.parser.data_path=/data/my_scene
```

---

## 5. CI / CD pipeline

A GitHub Actions workflow (`.github/workflows/docker.yml`) builds and pushes
the image automatically:

- **Push to `main`** → builds and pushes `:latest` + `:sha-<short>` tags
- **Semver tag** (e.g. `v1.2.3`) → also pushes `:1.2.3` and `:1.2` tags
- **Pull requests** → build-only (no push)

The image is published to the GitHub Container Registry at:

```
ghcr.io/bjoernellens1/gaussian-splatting-lightning
```

---

## 6. Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PYTORCH_ROCM_ARCH` | `gfx1151` | ROCm GPU architecture |
| `HSA_OVERRIDE_GFX_VERSION` | `11.5.1` | Forces ROCm to treat the GPU as gfx1151 at runtime |
| `IMAGE` | `ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest` | Image used by `run.sh` |
| `CONTAINER_NAME` | `gspl` | Container name used by `run.sh` |
| `DATA_DIR` | *(unset)* | Host path mounted as `/data` inside the container (uncomment in `run.sh`) |
