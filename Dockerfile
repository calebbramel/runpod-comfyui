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
# Startup script — provisions models from network volume at container start
# ---------------------------------------------------------------------------
# On first cold start, downloads missing models to the attached network volume.
# Subsequent starts are instant — models persist on the volume.
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

ENTRYPOINT ["/bin/bash", "/startup.sh"]

# ---------------------------------------------------------------------------
# Static Input Files (optional)
# ---------------------------------------------------------------------------
# Place workflow reference images, watermarks, or template videos in ./input/
# COPY input/ /comfyui/input/
