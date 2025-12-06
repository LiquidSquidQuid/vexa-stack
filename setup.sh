#!/bin/bash

# Vexa Stack Setup Script for RunPod
# Automatically configures ComfyUI with models, nodes, and workflows
# Works with any port configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Vexa Stack Setup for RunPod ===${NC}"
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

# Try Google Drive download if models are missing
if [ ! -f "$COMFYUI_DIR/models/checkpoints/ponyRealism_v22MainVAE.safetensors" ]; then
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