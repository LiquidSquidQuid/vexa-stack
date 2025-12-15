#!/bin/bash

# Vexa Stack Setup Script for RunPod
# Automatically configures ComfyUI with models, nodes, and workflows
# Works with any port configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Vexa Stack Setup for RunPod ===${NC}"
echo ""

# Installation type selection menu
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           SELECT INSTALLATION TYPE                            ║${NC}"
echo -e "${BOLD}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}                                                               ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${CYAN}1)${NC} Text-to-Image only                                       ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}     ${DIM}Photorealistic image generation with SDXL${NC}               ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}     ${GREEN}Required: ~7 GB${NC}  ${DIM}| Optional: +43 GB | Total: ~50 GB${NC}    ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}                                                               ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${CYAN}2)${NC} Image-to-Video only                                      ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}     ${DIM}Video generation with MEGA v12 + Wan 2.1${NC}               ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}     ${GREEN}Required: ~25 GB${NC} ${DIM}| Optional: +31 GB | Total: ~56 GB${NC}    ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}                                                               ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${CYAN}3)${NC} Full Stack (T2I + I2V)                                   ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}     ${DIM}Both image generation and video capabilities${NC}           ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}     ${GREEN}Required: ~32 GB${NC} ${DIM}| Optional: +74 GB | Total: ~106 GB${NC}   ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}                                                               ${BOLD}║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${DIM}Note: 'Required' = essential models, 'Optional' = alternatives${NC}"
echo ""
read -p "Enter choice [1-3, default=3]: " INSTALL_TYPE
INSTALL_TYPE=${INSTALL_TYPE:-3}

case $INSTALL_TYPE in
    1)
        INSTALL_CATEGORY="t2i"
        echo -e "${GREEN}✓ Selected: Text-to-Image only${NC}"
        ;;
    2)
        INSTALL_CATEGORY="i2v"
        echo -e "${GREEN}✓ Selected: Image-to-Video only${NC}"
        ;;
    *)
        INSTALL_CATEGORY="all"
        echo -e "${GREEN}✓ Selected: Full Stack (T2I + I2V)${NC}"
        ;;
esac

export INSTALL_CATEGORY
echo ""
echo "Initializing environment detection..."

# Source the environment detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/detect_environment.sh"

# Detect ComfyUI installation and port
detect_comfyui_installation
detect_comfyui_port

if [ -z "$COMFYUI_DIR" ]; then
    echo -e "${RED}Error: Could not find ComfyUI installation${NC}"
    echo "Please ensure ComfyUI is installed in one of these locations:"
    echo "  /workspace/ComfyUI"
    echo "  /workspace/comfyui"
    echo "  /comfyui"
    exit 1
fi

echo -e "${GREEN}✓ Found ComfyUI at: $COMFYUI_DIR${NC}"
echo -e "${GREEN}✓ ComfyUI running on port: $COMFYUI_PORT${NC}"

# Offer cleanup of stale files from previous installations
echo ""
read -p "Clean up stale models/workflows from previous installs? [y/N]: " CLEANUP_CHOICE
if [[ $CLEANUP_CHOICE =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Scanning for stale files...${NC}"
    bash "$SCRIPT_DIR/scripts/cleanup_stale.sh" "$COMFYUI_DIR" --dry-run
    echo ""
    read -p "Proceed with deletion? [y/N]: " CONFIRM_DELETE
    if [[ $CONFIRM_DELETE =~ ^[Yy]$ ]]; then
        bash "$SCRIPT_DIR/scripts/cleanup_stale.sh" "$COMFYUI_DIR" --force
    else
        echo -e "${YELLOW}Cleanup skipped.${NC}"
    fi
fi

# Update ComfyUI to latest version
echo -e "\n${YELLOW}Updating ComfyUI to latest version...${NC}"
cd "$COMFYUI_DIR"
git pull origin master || git pull origin main || {
    echo -e "${YELLOW}Warning: Could not update ComfyUI (not a git repo or no internet)${NC}"
}

# Update ComfyUI dependencies
if [ -f "requirements.txt" ]; then
    echo -e "${YELLOW}Updating ComfyUI dependencies...${NC}"
    pip install -r requirements.txt -q || {
        echo -e "${YELLOW}Warning: Some dependencies may have failed to install${NC}"
    }
fi
cd - > /dev/null
echo -e "${GREEN}✓ ComfyUI updated${NC}"

# Install common dependencies for custom nodes
echo -e "${YELLOW}Installing Python dependencies for custom nodes...${NC}"

# Critical dependencies - install individually to catch failures
for pkg in scikit-image numexpr imageio-ffmpeg; do
    pip install -q "$pkg" || echo -e "${RED}Failed to install $pkg${NC}"
done

# Optional dependencies
pip install -q piexif dill ultralytics 2>/dev/null || true

echo -e "${GREEN}✓ Node dependencies installed${NC}"

# Detect GPU
GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "No GPU detected")
echo -e "${GREEN}✓ GPU: $GPU_INFO${NC}"

# Create necessary directories
echo -e "\n${YELLOW}Setting up directories...${NC}"
mkdir -p "$COMFYUI_DIR/models/checkpoints"
mkdir -p "$COMFYUI_DIR/models/loras"
mkdir -p "$COMFYUI_DIR/models/vae"
mkdir -p "$COMFYUI_DIR/models/embeddings"
mkdir -p "$COMFYUI_DIR/models/controlnet"
mkdir -p "$COMFYUI_DIR/models/diffusion_models"
mkdir -p "$COMFYUI_DIR/models/text_encoders"
mkdir -p "$COMFYUI_DIR/models/clip_vision"
mkdir -p "$COMFYUI_DIR/models/upscale_models"
mkdir -p "$COMFYUI_DIR/models/insightface"
mkdir -p "$COMFYUI_DIR/models/facerestore_models"
mkdir -p "$COMFYUI_DIR/custom_nodes"
mkdir -p "$COMFYUI_DIR/workflows"

# Install gdown for Google Drive support
echo -e "\n${YELLOW}Checking Google Drive support...${NC}"
if ! command -v gdown &> /dev/null; then
    echo -e "Installing gdown for Google Drive downloads..."
    pip install --upgrade --no-cache-dir gdown -q || {
        echo -e "${YELLOW}Warning: Could not install gdown, Google Drive downloads may fail${NC}"
    }
fi

# Download models
echo -e "\n${YELLOW}Downloading models...${NC}"
bash "$SCRIPT_DIR/scripts/inject_models.sh" "$COMFYUI_DIR"

# Try Google Drive download if primary model is missing
if [ ! -f "$COMFYUI_DIR/models/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors" ]; then
    echo -e "\n${YELLOW}Attempting Google Drive download for missing models...${NC}"
    bash "$SCRIPT_DIR/scripts/download_from_gdrive.sh" "$COMFYUI_DIR" || {
        echo -e "${YELLOW}Some models may need manual upload to Google Drive${NC}"
        echo -e "Drive folder: https://drive.google.com/drive/folders/1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L"
    }
fi

# Install custom nodes
echo -e "\n${YELLOW}Installing custom nodes...${NC}"
bash "$SCRIPT_DIR/scripts/inject_nodes.sh" "$COMFYUI_DIR"

# Copy workflows
echo -e "\n${YELLOW}Copying workflows...${NC}"
bash "$SCRIPT_DIR/scripts/inject_workflows.sh" "$COMFYUI_DIR" "$COMFYUI_PORT"

# Run health check
echo -e "\n${YELLOW}Running health check...${NC}"
bash "$SCRIPT_DIR/utils/health_check.sh" "$COMFYUI_DIR" "$COMFYUI_PORT"

# Check if restart is needed
if [ -f "/tmp/comfyui_restart_required" ]; then
    echo -e "\n${YELLOW}Restarting ComfyUI to load new nodes...${NC}"
    bash "$SCRIPT_DIR/scripts/restart_comfyui.sh" "$COMFYUI_PORT"
    rm /tmp/comfyui_restart_required
fi

echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
echo -e "Access ComfyUI at: http://localhost:${COMFYUI_PORT}"
echo -e "Workflows available in: Load → vexa_*"
echo -e "\nTo manually restart ComfyUI: ${YELLOW}bash $SCRIPT_DIR/scripts/restart_comfyui.sh${NC}"
echo -e "To download additional models: ${YELLOW}bash $SCRIPT_DIR/scripts/inject_models.sh${NC}"
echo -e "To cleanup stale files: ${YELLOW}bash $SCRIPT_DIR/scripts/cleanup_stale.sh${NC}"