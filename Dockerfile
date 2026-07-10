# =============================================================================
# Custom RunPod ComfyUI Worker Image — Video Generation
# =============================================================================
# WAN 2.2 + LTX 2.3 — BF16/FP16
# Target GPU: 96 GB VRAM (2× A6000 / A100 / H100)
# =============================================================================
# Build:
#   docker build --platform linux/amd64 -t <your-registry>/comfyui-video:<tag> .
#   docker push <your-registry>/comfyui-video:<tag>
# =============================================================================

FROM runpod/worker-comfyui:5.8.6-base

# ---------------------------------------------------------------------------
# Video Generation Nodes
# ---------------------------------------------------------------------------

# All custom nodes in one layer — video gen + QoL
RUN comfy-node-install \
    ComfyUI-WanVideoWrapper \
    ComfyUI-LTXVideo \
    ComfyUI-VideoHelperSuite \
    ComfyUI-GGUF \
    ComfyUI-FlashVSR \
    ComfyUI-KJNodes \
    rgthree-comfy \
    efficiency-nodes-comfyui \
    comfyui-tooling-nodes \
    ComfyUI-Manager

# ---------------------------------------------------------------------------
# Models — baked into the image (~36 GB)
# ---------------------------------------------------------------------------
# LTX 2.3 distilled checkpoint + Gemma 3 12B text encoder.
# Lives in the image so serverless cold starts don't depend on a network volume.
RUN mkdir -p /comfyui/models/checkpoints /comfyui/models/text_encoders && \
    wget --progress=bar:force -q --show-progress \
        -O /comfyui/models/checkpoints/ltx-2.3-22b-distilled-1.1.safetensors \
        "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-1.1.safetensors" && \
    wget --progress=bar:force -q --show-progress \
        -O /comfyui/models/text_encoders/gemma_3_12B_it.safetensors \
        "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it.safetensors" && \
    echo "=== Models downloaded ==="

# ---------------------------------------------------------------------------
# Static Input Files (optional)
# ---------------------------------------------------------------------------
# Place workflow reference images, watermarks, or template videos in ./input/
# COPY input/ /comfyui/input/
