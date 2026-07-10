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
# Downgrade PyTorch from cu130 → cu121 (compatible with older NVIDIA drivers)
# The base image ships torch 2.12.0+cu130 which requires driver ≥ r570 (CUDA 13).
# Some RunPod pods still have older drivers. cu121 works with driver ≥ r525 (CUDA 12).
# ---------------------------------------------------------------------------
RUN pip install --no-cache-dir \
    torch==2.5.1+cu121 \
    torchvision==0.20.1+cu121 \
    torchaudio==2.5.1+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# ---------------------------------------------------------------------------
# Video Generation Nodes
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Python dependencies required by custom nodes, pinned for compatibility
# ---------------------------------------------------------------------------
RUN pip install --no-cache-dir \
    gguf>=0.17.1 \
    accelerate>=1.2.1 \
    "kornia==0.7.2" \
    ftfy

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
# Model & Input Symlinks → Network Volume
# ---------------------------------------------------------------------------
# At runtime the Network Volume is mounted at /runpod-volume. These symlinks
# make models and input files visible to ComfyUI. They're broken at build
# time but resolve when the volume is attached.
RUN for subdir in checkpoints text_encoders vae diffusion_models clip_vision loras upscale_models; do \
        rm -rf /comfyui/models/${subdir} && \
        ln -sf /runpod-volume/models/${subdir} /comfyui/models/${subdir}; \
    done && \
    rm -rf /comfyui/input && ln -sf /runpod-volume/input /comfyui/input

# ---------------------------------------------------------------------------
# Startup script — auto-downloads missing models at container start
# ---------------------------------------------------------------------------
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh
ENTRYPOINT ["/startup.sh"]