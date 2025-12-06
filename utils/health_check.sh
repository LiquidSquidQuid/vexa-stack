#!/bin/bash

# Health check script for ComfyUI installation
# Verifies models, nodes, and API accessibility

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
COMFYUI_PORT="${2:-8188}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== ComfyUI Health Check ===${NC}\n"

# Track overall health
HEALTH_SCORE=0
MAX_SCORE=0

# Function to check and report
check_item() {
    local name="$1"
    local condition="$2"
    local required="${3:-false}"
    
    MAX_SCORE=$((MAX_SCORE + 1))
    
    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} $name"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
        return 0
    else
        if [ "$required" == "true" ]; then
            echo -e "${RED}✗${NC} $name (REQUIRED)"
        else
            echo -e "${YELLOW}⚠${NC} $name (optional)"
        fi
        return 1
    fi
}

# Check ComfyUI installation
echo -e "${YELLOW}Checking ComfyUI Installation...${NC}"
check_item "ComfyUI directory exists" "[ -d '$COMFYUI_DIR' ]" true
check_item "main.py exists" "[ -f '$COMFYUI_DIR/main.py' ]" true
check_item "requirements.txt exists" "[ -f '$COMFYUI_DIR/requirements.txt' ]"

# Check API accessibility
echo -e "\n${YELLOW}Checking API Accessibility...${NC}"
check_item "ComfyUI API responds on port $COMFYUI_PORT" \
    "curl -s 'http://localhost:$COMFYUI_PORT/system_stats' > /dev/null 2>&1"

# Check models
echo -e "\n${YELLOW}Checking Models...${NC}"
check_item "Checkpoints directory exists" "[ -d '$COMFYUI_DIR/models/checkpoints' ]" true
check_item "RealVisXL model" "[ -f '$COMFYUI_DIR/models/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors' ]"
check_item "Pony Realism model" "[ -f '$COMFYUI_DIR/models/checkpoints/ponyRealism_v22MainVAE.safetensors' ]"
check_item "VAE directory exists" "[ -d '$COMFYUI_DIR/models/vae' ]"
check_item "SDXL VAE" "[ -f '$COMFYUI_DIR/models/vae/sdxl_vae.safetensors' ]"
check_item "LoRA directory exists" "[ -d '$COMFYUI_DIR/models/loras' ]"

# Count models
if [ -d "$COMFYUI_DIR/models/checkpoints" ]; then
    checkpoint_count=$(find "$COMFYUI_DIR/models/checkpoints" -name "*.safetensors" -o -name "*.ckpt" | wc -l)
    echo -e "  Found $checkpoint_count checkpoint model(s)"
fi

if [ -d "$COMFYUI_DIR/models/loras" ]; then
    lora_count=$(find "$COMFYUI_DIR/models/loras" -name "*.safetensors" -o -name "*.pt" | wc -l)
    echo -e "  Found $lora_count LoRA model(s)"
fi

# Check custom nodes
echo -e "\n${YELLOW}Checking Custom Nodes...${NC}"
check_item "Custom nodes directory exists" "[ -d '$COMFYUI_DIR/custom_nodes' ]" true
check_item "ComfyUI Manager" "[ -d '$COMFYUI_DIR/custom_nodes/ComfyUI-Manager' ]"
check_item "IPAdapter Plus" "[ -d '$COMFYUI_DIR/custom_nodes/ComfyUI_IPAdapter_plus' ]"
check_item "Impact Pack" "[ -d '$COMFYUI_DIR/custom_nodes/ComfyUI-Impact-Pack' ]"

# Count custom nodes
if [ -d "$COMFYUI_DIR/custom_nodes" ]; then
    node_count=$(find "$COMFYUI_DIR/custom_nodes" -maxdepth 1 -type d | wc -l)
    node_count=$((node_count - 1))  # Subtract the directory itself
    echo -e "  Found $node_count custom node(s)"
fi

# Check workflows
echo -e "\n${YELLOW}Checking Workflows...${NC}"
check_item "Workflows directory exists" "[ -d '$COMFYUI_DIR/workflows' ] || [ -d '$COMFYUI_DIR/user/default/workflows' ]"

workflow_dir=""
if [ -d "$COMFYUI_DIR/workflows" ]; then
    workflow_dir="$COMFYUI_DIR/workflows"
elif [ -d "$COMFYUI_DIR/user/default/workflows" ]; then
    workflow_dir="$COMFYUI_DIR/user/default/workflows"
fi

if [ -n "$workflow_dir" ]; then
    workflow_count=$(find "$workflow_dir" -name "*.json" | wc -l)
    echo -e "  Found $workflow_count workflow(s)"
    
    # Check for Vexa workflows
    vexa_count=$(find "$workflow_dir" -name "vexa_*.json" | wc -l)
    if [ $vexa_count -gt 0 ]; then
        echo -e "  ${GREEN}Found $vexa_count Vexa workflow(s)${NC}"
    fi
fi

# Check Python environment
echo -e "\n${YELLOW}Checking Python Environment...${NC}"
if command -v python &> /dev/null; then
    python_version=$(python --version 2>&1)
    echo -e "  Python: $python_version"
fi

if command -v pip &> /dev/null; then
    # Check for key packages
    check_item "torch installed" "python -c 'import torch' 2>/dev/null"
    check_item "numpy installed" "python -c 'import numpy' 2>/dev/null"
    check_item "PIL installed" "python -c 'import PIL' 2>/dev/null"
fi

# Check GPU
echo -e "\n${YELLOW}Checking GPU...${NC}"
if command -v nvidia-smi &> /dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)
    echo -e "  ${GREEN}GPU: $gpu_info${NC}"
    
    # Check CUDA
    if python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q "True"; then
        echo -e "  ${GREEN}✓ CUDA available${NC}"
    else
        echo -e "  ${YELLOW}⚠ CUDA not available${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ No NVIDIA GPU detected${NC}"
fi

# Check disk space
echo -e "\n${YELLOW}Checking Disk Space...${NC}"
available_space=$(df -h "$COMFYUI_DIR" | tail -1 | awk '{print $4}')
echo -e "  Available space: $available_space"

# Summary
echo -e "\n${BLUE}=== Health Check Summary ===${NC}"
echo -e "Score: $HEALTH_SCORE/$MAX_SCORE"

if [ $HEALTH_SCORE -eq $MAX_SCORE ]; then
    echo -e "${GREEN}✓ All checks passed! ComfyUI is fully configured.${NC}"
elif [ $HEALTH_SCORE -gt $((MAX_SCORE * 3 / 4)) ]; then
    echo -e "${GREEN}✓ ComfyUI is mostly configured and should work.${NC}"
elif [ $HEALTH_SCORE -gt $((MAX_SCORE / 2)) ]; then
    echo -e "${YELLOW}⚠ ComfyUI is partially configured. Some features may not work.${NC}"
else
    echo -e "${RED}✗ ComfyUI configuration incomplete. Please run setup.sh${NC}"
fi

# Provide recommendations if needed
if [ $HEALTH_SCORE -lt $MAX_SCORE ]; then
    echo -e "\n${YELLOW}Recommendations:${NC}"
    
    if ! curl -s "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
        echo -e "  - Start ComfyUI: bash scripts/restart_comfyui.sh"
    fi
    
    if [ ! -f "$COMFYUI_DIR/models/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors" ]; then
        echo -e "  - Download models: bash scripts/inject_models.sh"
    fi
    
    if [ ! -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
        echo -e "  - Install custom nodes: bash scripts/inject_nodes.sh"
    fi
fi