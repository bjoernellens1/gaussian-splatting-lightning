#!/usr/bin/env bash
# run.sh – Launch gaussian-splatting-lightning with ROCm GPU access.
#
# Compatible with both Docker and Podman.
# Usage:
#   ./run.sh [extra container args...]
#
# Examples:
#   ./run.sh                          # interactive shell
#   ./run.sh python main.py ...       # run a specific command
#   IMAGE=my-registry/gspl:latest ./run.sh

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
IMAGE="${IMAGE:-ghcr.io/bjoernellens1/gaussian-splatting-lightning:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-gspl}"
WORKDIR="${WORKDIR:-/app/gaussian-splatting-lightning}"

# ── Runtime auto-detection (prefer Podman when both are present) ───────────────
if command -v podman &>/dev/null; then
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
else
    echo "ERROR: Neither 'podman' nor 'docker' found in PATH." >&2
    exit 1
fi
echo "[run.sh] Using runtime: ${RUNTIME}"

# ── ROCm device flags ──────────────────────────────────────────────────────────
DEVICE_FLAGS=(
    --device /dev/dri
    --device /dev/kfd
)

# ── Group flags (allow the container user to access GPU render nodes) ──────────
GROUP_FLAGS=(
    --group-add video
    --group-add render
    # sudo group membership may be required by some ROCm / HSA initialisation
    # paths on certain distros.  Remove if your workload does not need it.
    --group-add sudo
)

# ── Security flags ─────────────────────────────────────────────────────────────
# seccomp=unconfined is required for some ROCm / HSA syscalls.
SECURITY_FLAGS=(
    --security-opt seccomp=unconfined
)

# ── Optional: mount a host directory as /data inside the container ────────────
# Set DATA_DIR to the path you want to expose, e.g.:
#   DATA_DIR=/path/to/my/scene ./run.sh
MOUNT_FLAGS=()
if [[ -n "${DATA_DIR:-}" ]]; then
    MOUNT_FLAGS+=(--volume "${DATA_DIR}:/data:z")
    echo "[run.sh] Mounting ${DATA_DIR} -> /data"
fi

# ── Podman-specific extras ─────────────────────────────────────────────────────
EXTRA_FLAGS=()
if [[ "${RUNTIME}" == "podman" ]]; then
    # Run rootless; map the current UID so volume-mounted files stay accessible.
    EXTRA_FLAGS+=(--userns=keep-id)
fi

# ── Launch ─────────────────────────────────────────────────────────────────────
exec "${RUNTIME}" run --rm -it \
    --name "${CONTAINER_NAME}" \
    --workdir "${WORKDIR}" \
    "${DEVICE_FLAGS[@]}" \
    "${GROUP_FLAGS[@]}" \
    "${SECURITY_FLAGS[@]}" \
    "${MOUNT_FLAGS[@]}" \
    "${EXTRA_FLAGS[@]}" \
    "${IMAGE}" \
    "${@:-/bin/bash}"
