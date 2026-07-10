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

# ---------------------------------------------------------------------------
# Python dependencies required by custom nodes, pinned for compatibility
# ---------------------------------------------------------------------------
RUN pip install --no-cache-dir \
    gguf>=0.17.1 \
    accelerate>=1.2.1 \
    "kornia==0.7.2"

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
    ComfyUI-Manager

# ---------------------------------------------------------------------------
# Models — all models live on the Network Volume, not in the image
# ---------------------------------------------------------------------------
# Use download-models.sh to populate your Network Volume:
#   1. Create a RunPod Network Volume in your endpoint's region (80+ GB)
#   2. Attach it to a temporary GPU pod
#   3. Run: bash download-models.sh /runpod-volume
#   4. Detach and attach it to your serverless endpoint
#
# The worker auto-detects models under /runpod-volume/models/:
#   /runpod-volume/models/
#   ├── diffusion_models/   ← WAN 2.1/2.2 (BF16/FP16)
#   ├── text_encoders/      ← UMT5-XXL, T5-XXL
#   ├── vae/                ← wan_2.1_vae, ltx VAE
#   ├── checkpoints/        ← LTX 2.3 distilled + upscalers
#   ├── upscale_models/     ← ESRGAN
#   ├── clip_vision/
#   └── loras/              ← anime style LoRAs

# ---------------------------------------------------------------------------
# Input Files via Network Volume
# ---------------------------------------------------------------------------
# Upload images/videos to your Network Volume under /input/.
# At runtime the volume is mounted at /runpod-volume, and this symlink
# makes those files visible to ComfyUI's Load Image/Load Video nodes.
RUN rm -rf /comfyui/input && ln -s /runpod-volume/input /comfyui/input
