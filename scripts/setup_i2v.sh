#!/bin/bash

# Quick setup script for Image-to-Video (Wan 2.2) on existing ComfyUI deployment
# Run this after the base vexa-stack setup is complete

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CHECK="✓"
DOWNLOAD="⬇"

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         WAN 2.2 IMAGE-TO-VIDEO SETUP                          ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create required directories
echo -e "${YELLOW}Creating model directories...${NC}"
mkdir -p "$COMFYUI_DIR/models/diffusion_models"
mkdir -p "$COMFYUI_DIR/models/text_encoders"
mkdir -p "$COMFYUI_DIR/models/clip_vision"
mkdir -p "$COMFYUI_DIR/models/vae"
mkdir -p "$COMFYUI_DIR/models/upscale_models"
echo -e "${GREEN}${CHECK} Directories created${NC}"

# Install required custom nodes
echo ""
echo -e "${BOLD}Installing required custom nodes...${NC}"

mkdir -p "$COMFYUI_DIR/custom_nodes"
cd "$COMFYUI_DIR/custom_nodes"

# VideoHelperSuite
if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
    echo -e "${CYAN}${DOWNLOAD} Installing ComfyUI-VideoHelperSuite...${NC}"
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    cd ComfyUI-VideoHelperSuite && pip install -r requirements.txt -q && cd ..
    echo -e "${GREEN}${CHECK} VideoHelperSuite installed${NC}"
else
    echo -e "${GREEN}${CHECK} VideoHelperSuite already installed${NC}"
fi

# Frame Interpolation (RIFE)
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    echo -e "${CYAN}${DOWNLOAD} Installing ComfyUI-Frame-Interpolation...${NC}"
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation && python install.py && cd ..
    echo -e "${GREEN}${CHECK} Frame Interpolation installed${NC}"
else
    echo -e "${GREEN}${CHECK} Frame Interpolation already installed${NC}"
fi

cd "$COMFYUI_DIR/models"

# Download Wan 2.2 I2V models
echo ""
echo -e "${BOLD}Downloading Wan 2.2 I2V models...${NC}"
echo -e "${YELLOW}This will download ~35GB of models. Please be patient.${NC}"
echo ""

# Wan 2.2 I2V High-Noise Model
if [ ! -f "diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" ]; then
    echo -e "${CYAN}${DOWNLOAD} Wan 2.2 I2V High-Noise Model (14GB)...${NC}"
    wget -c --progress=bar:force:noscroll -q --show-progress \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
        -O "diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
    echo -e "${GREEN}${CHECK} High-Noise model downloaded${NC}"
else
    echo -e "${GREEN}${CHECK} High-Noise model exists${NC}"
fi

# Wan 2.2 I2V Low-Noise Model
if [ ! -f "diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" ]; then
    echo -e "${CYAN}${DOWNLOAD} Wan 2.2 I2V Low-Noise Model (14GB)...${NC}"
    wget -c --progress=bar:force:noscroll -q --show-progress \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
        -O "diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
    echo -e "${GREEN}${CHECK} Low-Noise model downloaded${NC}"
else
    echo -e "${GREEN}${CHECK} Low-Noise model exists${NC}"
fi

# Wan VAE
if [ ! -f "vae/wan_2.1_vae.safetensors" ]; then
    echo -e "${CYAN}${DOWNLOAD} Wan VAE (335MB)...${NC}"
    wget -c --progress=bar:force:noscroll -q --show-progress \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
        -O "vae/wan_2.1_vae.safetensors"
    echo -e "${GREEN}${CHECK} Wan VAE downloaded${NC}"
else
    echo -e "${GREEN}${CHECK} Wan VAE exists${NC}"
fi

# UMT5 Text Encoder
if [ ! -f "text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    echo -e "${CYAN}${DOWNLOAD} UMT5 Text Encoder (5GB)...${NC}"
    wget -c --progress=bar:force:noscroll -q --show-progress \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        -O "text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    echo -e "${GREEN}${CHECK} UMT5 Text Encoder downloaded${NC}"
else
    echo -e "${GREEN}${CHECK} UMT5 Text Encoder exists${NC}"
fi

# CLIP Vision H
if [ ! -f "clip_vision/clip_vision_h.safetensors" ]; then
    echo -e "${CYAN}${DOWNLOAD} CLIP Vision H (2GB)...${NC}"
    wget -c --progress=bar:force:noscroll -q --show-progress \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
        -O "clip_vision/clip_vision_h.safetensors"
    echo -e "${GREEN}${CHECK} CLIP Vision H downloaded${NC}"
else
    echo -e "${GREEN}${CHECK} CLIP Vision H exists${NC}"
fi

# RealESRGAN Upscaler
if [ ! -f "upscale_models/RealESRGAN_x4plus.pth" ]; then
    echo -e "${CYAN}${DOWNLOAD} RealESRGAN x4plus (64MB)...${NC}"
    wget -c --progress=bar:force:noscroll -q --show-progress \
        "https://huggingface.co/fofr/comfyui/resolve/main/upscale_models/RealESRGAN_x4plus.pth" \
        -O "upscale_models/RealESRGAN_x4plus.pth"
    echo -e "${GREEN}${CHECK} RealESRGAN downloaded${NC}"
else
    echo -e "${GREEN}${CHECK} RealESRGAN exists${NC}"
fi

# Summary
echo ""
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║         I2V SETUP COMPLETE                                    ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Models downloaded:${NC}"
echo -e "  ${CHECK} wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
echo -e "  ${CHECK} wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
echo -e "  ${CHECK} wan_2.1_vae.safetensors"
echo -e "  ${CHECK} umt5_xxl_fp8_e4m3fn_scaled.safetensors"
echo -e "  ${CHECK} clip_vision_h.safetensors"
echo -e "  ${CHECK} RealESRGAN_x4plus.pth"
echo ""
echo -e "${BOLD}Custom nodes installed:${NC}"
echo -e "  ${CHECK} ComfyUI-VideoHelperSuite"
echo -e "  ${CHECK} ComfyUI-Frame-Interpolation"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Restart ComfyUI if running"
echo -e "  2. Load the workflow: ${CYAN}wan22_i2v_upscale_interp.json${NC}"
echo -e "  3. Upload your source image and adjust prompts"
echo ""
echo -e "${GREEN}Happy video generating!${NC}"
