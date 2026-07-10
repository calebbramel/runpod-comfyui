#!/bin/bash
# =============================================================================
# RunPod ComfyUI Startup — Network Volume Model Provisioner
# =============================================================================
# Runs at container start. Checks the network volume for required models,
# downloads any that are missing, and symlinks them into ComfyUI's model dirs.
#
# First cold start with an empty volume will be slow (~36 GB download).
# Subsequent starts are instant — models persist on the network volume.
# =============================================================================

set -euo pipefail

VOLUME="/runpod-volume"
MODELS_DIR="${VOLUME}/models"

download() {
    local url="$1"; local dir="$2"; local filename="$3"; local dest="${dir}/${filename}"
    if [[ -f "$dest" ]]; then
        echo "  [OK] ${filename}"
    else
        echo "  [DOWNLOAD] ${filename} ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
        wget --progress=bar:force -q --show-progress -O "${dest}.tmp" "$url" && mv "${dest}.tmp" "$dest"
        echo "  [DONE]  ${filename} ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
    fi
}

# ---------------------------------------------------------------------------
# Only run if a network volume is attached
# ---------------------------------------------------------------------------
# Detect network volume — try mountpoint, fall back to checking if it's a mount
if [ -d "$VOLUME" ] && { mountpoint -q "$VOLUME" 2>/dev/null || df "$VOLUME" 2>/dev/null | grep -q "$VOLUME"; }; then
    echo "=== Network volume detected at ${VOLUME} ==="

    mkdir -p "${MODELS_DIR}"/{checkpoints,text_encoders,vae,diffusion_models,clip_vision,loras,upscale_models}

    # ---------------------------------------------------------------------------
    # LTX 2.3 — required for rezero_base64.json workflow
    # ---------------------------------------------------------------------------
    echo ""
    echo "=== LTX 2.3 Checkpoint (~22 GB) ==="
    download \
        "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-1.1.safetensors" \
        "${MODELS_DIR}/checkpoints" \
        "ltx-2.3-22b-distilled-1.1.safetensors"

    echo ""
    echo "=== Gemma 3 12B Text Encoder (~24 GB) ==="
    download \
        "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it.safetensors" \
        "${MODELS_DIR}/text_encoders" \
        "gemma_3_12B_it.safetensors"

    # ---------------------------------------------------------------------------
    # Symlink network volume models → /comfyui/models so ComfyUI sees them
    # ---------------------------------------------------------------------------
    echo ""
    echo "=== Symlinking into /comfyui/models ==="
    for subdir in checkpoints text_encoders vae diffusion_models clip_vision loras upscale_models; do
        if [ -d "${MODELS_DIR}/${subdir}" ]; then
            # If ComfyUI already has a real dir with files, migrate them into the volume
            if [ -d "/comfyui/models/${subdir}" ] && [ ! -L "/comfyui/models/${subdir}" ]; then
                echo "  migrating existing ${subdir}/ to network volume"
                mkdir -p "${MODELS_DIR}/${subdir}"
                find "/comfyui/models/${subdir}" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
                    base=$(basename "$f")
                    if [ ! -f "${MODELS_DIR}/${subdir}/${base}" ]; then
                        mv "$f" "${MODELS_DIR}/${subdir}/"
                    fi
                done
                rm -rf "/comfyui/models/${subdir}"
            fi
            if [ ! -e "/comfyui/models/${subdir}" ]; then
                ln -sf "${MODELS_DIR}/${subdir}" "/comfyui/models/${subdir}"
                echo "  ${subdir} → ${MODELS_DIR}/${subdir}"
            fi
        fi
    done

    echo ""
    echo "=== Startup provisioning complete ==="
else
    echo "=== No network volume detected, skipping model provisioning ==="
fi

# ---------------------------------------------------------------------------
# Start ComfyUI in the background
# ---------------------------------------------------------------------------
echo ""
echo "=== Starting ComfyUI ==="

# Disable manager network calls — everything should be pre-installed
comfy-manager-set-mode offline 2>/dev/null || true

cd /comfyui
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch --disable-metadata &
COMFY_PID=$!
echo "${COMFY_PID}" > /tmp/comfyui.pid
echo "ComfyUI PID: ${COMFY_PID}"

# Wait for the API to come up
echo "=== Waiting for ComfyUI API ==="
for i in $(seq 1 120); do
    if curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
        echo "ComfyUI API ready after ${i}s"
        break
    fi
    if ! kill -0 "${COMFY_PID}" 2>/dev/null; then
        echo "ERROR: ComfyUI process died! Check logs above."
        exit 1
    fi
    sleep 1
done

# ---------------------------------------------------------------------------
# Hand off to the base image's RunPod worker
# ---------------------------------------------------------------------------
exec python -u /handler.py
