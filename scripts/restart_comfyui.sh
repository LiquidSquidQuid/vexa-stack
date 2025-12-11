#!/bin/bash

# ComfyUI restart script
# Gracefully restarts ComfyUI preserving port and settings

set -e

COMFYUI_PORT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== ComfyUI Restart Script ===${NC}"

# Source environment detection if not already done
source "$SCRIPT_DIR/detect_environment.sh"

# If port not provided, try to detect it
if [ -z "$COMFYUI_PORT" ]; then
    detect_comfyui_port
fi

echo -e "Detected port: $COMFYUI_PORT"

# Find ComfyUI process
COMFY_PID=$(ps aux | grep -E "python.*main\.py" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$COMFY_PID" ]; then
    echo -e "${YELLOW}ComfyUI is not currently running${NC}"
    echo -e "Starting ComfyUI on port $COMFYUI_PORT..."
else
    echo -e "${YELLOW}Found ComfyUI process: PID $COMFY_PID${NC}"
    
    # Get current command line arguments
    COMFY_CMD=$(ps aux | grep -E "python.*main\.py" | grep -v grep | head -1)
    echo -e "Current command: ${COMFY_CMD:0:100}..."
    
    # Stop ComfyUI gracefully
    echo -e "${YELLOW}Stopping ComfyUI...${NC}"
    kill -SIGTERM "$COMFY_PID" 2>/dev/null || true
    
    # Wait for process to stop (max 10 seconds)
    count=0
    while kill -0 "$COMFY_PID" 2>/dev/null && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    echo ""
    
    # Force kill if still running
    if kill -0 "$COMFY_PID" 2>/dev/null; then
        echo -e "${YELLOW}Force stopping ComfyUI...${NC}"
        kill -SIGKILL "$COMFY_PID" 2>/dev/null || true
        sleep 2
    fi
    
    echo -e "${GREEN}✓ ComfyUI stopped${NC}"
fi

# Detect ComfyUI directory if not already done
if [ -z "$COMFYUI_DIR" ]; then
    detect_comfyui_installation
fi

if [ -z "$COMFYUI_DIR" ] || [ ! -f "$COMFYUI_DIR/main.py" ]; then
    echo -e "${RED}Error: Could not find ComfyUI installation${NC}"
    exit 1
fi

# Start ComfyUI with appropriate arguments
echo -e "\n${YELLOW}Starting ComfyUI...${NC}"
cd "$COMFYUI_DIR"

# Detect python command (python3 on most systems, python in some venvs)
PYTHON_CMD="python3"
if ! command -v python3 &> /dev/null; then
    PYTHON_CMD="python"
fi

# Build command with common arguments
CMD="$PYTHON_CMD main.py --listen 0.0.0.0 --port $COMFYUI_PORT"

# Add GPU/CUDA optimizations if available
if command -v nvidia-smi &> /dev/null; then
    # Add CUDA optimizations
    export CUDA_VISIBLE_DEVICES=0
    CMD="$CMD --gpu-only"
fi

# Check for low VRAM mode and warn about I2V requirements
VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
if [ -n "$VRAM_MB" ]; then
    echo -e "Detected VRAM: ${VRAM_MB} MB"

    # Enable low VRAM mode if < 8GB
    if [ "$VRAM_MB" -lt 8000 ]; then
        echo -e "${YELLOW}Low VRAM detected, enabling --lowvram mode${NC}"
        CMD="$CMD --lowvram"
    fi

    # Warn about I2V model requirements
    if [ "$VRAM_MB" -lt 16000 ]; then
        # Check if I2V models are present
        if [ -d "$COMFYUI_DIR/models/diffusion_models" ]; then
            I2V_COUNT=$(find "$COMFYUI_DIR/models/diffusion_models" -name "*.safetensors" 2>/dev/null | wc -l)
            if [ "$I2V_COUNT" -gt 0 ]; then
                echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${YELLOW}║  WARNING: I2V models detected but VRAM may be insufficient    ║${NC}"
                echo -e "${YELLOW}║  Wan 2.2 I2V models require 16GB+ VRAM for optimal use        ║${NC}"
                echo -e "${YELLOW}║  Current VRAM: ${VRAM_MB} MB                                         ║${NC}"
                echo -e "${YELLOW}║  Consider using --lowvram or reducing frame count/resolution  ║${NC}"
                echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
            fi
        fi
    fi
fi

# Add preview method
CMD="$CMD --preview-method auto"

echo -e "Starting with command: $CMD"

# Start ComfyUI in background
nohup $CMD > /tmp/comfyui_$COMFYUI_PORT.log 2>&1 &
NEW_PID=$!

echo -e "${GREEN}✓ ComfyUI started with PID: $NEW_PID${NC}"

# Wait for ComfyUI to be ready
echo -e "\n${YELLOW}Waiting for ComfyUI to be ready...${NC}"
count=0
max_wait=30

while [ $count -lt $max_wait ]; do
    if curl -s "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
        echo -e "\n${GREEN}✓ ComfyUI is ready!${NC}"
        echo -e "Access at: http://localhost:$COMFYUI_PORT"
        break
    fi
    sleep 1
    count=$((count + 1))
    echo -n "."
done

if [ $count -eq $max_wait ]; then
    echo -e "\n${RED}Warning: ComfyUI may not have started correctly${NC}"
    echo -e "Check logs at: /tmp/comfyui_$COMFYUI_PORT.log"
    echo -e "Last few lines of log:"
    tail -5 /tmp/comfyui_$COMFYUI_PORT.log
fi

echo -e "\n${GREEN}=== Restart Complete ===${NC}"