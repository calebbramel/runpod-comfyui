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

# WAN Video — WAN 2.2, VACE, Fun, Phantom, ReCamMaster
RUN comfy-node-install ComfyUI-WanVideoWrapper

# WanAnimate Enhancer — anime motion/expression/pose control
RUN comfy-node-install ComfyUI-WanAnimate-Enhancer

# LTX-Video — fast I2V/T2V
RUN comfy-node-install ComfyUI-LTXVideo

# Video Helper Suite — load, combine, export video files
RUN comfy-node-install ComfyUI-VideoHelperSuite

# GGUF — quantized model support
RUN comfy-node-install ComfyUI-GGUF

# FlashVSR — diffusion-based video super resolution (2×/4× upscale to 1080p/4K)
RUN comfy-node-install ComfyUI-FlashVSR

# KJNodes — advanced video workflow utilities (grow masks, batch tools)
RUN comfy-node-install ComfyUI-KJNodes

# ---------------------------------------------------------------------------
# Quality-of-Life Nodes
# ---------------------------------------------------------------------------

# rgthree — seed control, power Lora loader, context, fast groups muter
RUN comfy-node-install rgthree-comfy

# Efficiency nodes — workflow management utilities
RUN comfy-node-install efficiency-nodes-comfyui

# ComfyUI Manager — install/update nodes from the UI
RUN comfy-node-install ComfyUI-Manager

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
# Static Input Files (optional)
# ---------------------------------------------------------------------------
# Place workflow reference images, watermarks, or template videos in ./input/
# COPY input/ /comfyui/input/
