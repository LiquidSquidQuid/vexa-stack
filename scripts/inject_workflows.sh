#!/bin/bash

# Workflow injection script for ComfyUI
# Copies workflow files to ComfyUI installation

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
COMFYUI_PORT="${2:-8188}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$SCRIPT_DIR/../workflows"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${GREEN}=== Workflow Injection for ComfyUI ===${NC}"

# Get install category from environment (default: all)
INSTALL_CATEGORY="${INSTALL_CATEGORY:-all}"
echo -e "Installation mode: ${BLUE}${INSTALL_CATEGORY}${NC}\n"

# Check if workflow directory exists
if [ ! -d "$WORKFLOW_DIR" ]; then
    echo -e "${RED}Error: Workflow directory not found: $WORKFLOW_DIR${NC}"
    exit 1
fi

# Find workflow files
workflow_count=$(find "$WORKFLOW_DIR" -name "*.json" -type f | wc -l)
if [ "$workflow_count" -eq 0 ]; then
    echo -e "${YELLOW}No workflow files found in $WORKFLOW_DIR${NC}"
    exit 0
fi

echo -e "${BLUE}Found $workflow_count total workflow(s)${NC}"

# Determine target directory for workflows
POSSIBLE_TARGETS=(
    "$COMFYUI_DIR/user/default/workflows"
    "$COMFYUI_DIR/workflows"
    "$COMFYUI_DIR/web/workflows"
    "$COMFYUI_DIR/custom_workflows"
)

TARGET_DIR=""
for dir in "${POSSIBLE_TARGETS[@]}"; do
    if [ -d "$(dirname "$dir")" ]; then
        TARGET_DIR="$dir"
        break
    fi
done

# If no existing workflow directory found, create one
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$COMFYUI_DIR/user/default/workflows"
    echo -e "${YELLOW}Creating workflow directory: $TARGET_DIR${NC}"
fi

mkdir -p "$TARGET_DIR"

echo -e "\n${YELLOW}Copying workflows to: $TARGET_DIR${NC}\n"

# Track counts
copied_count=0
skipped_count=0

# Copy Text to Image workflows
T2I_DIR="$WORKFLOW_DIR/Text to Image"
if [ -d "$T2I_DIR" ]; then
    if [ "$INSTALL_CATEGORY" == "all" ] || [ "$INSTALL_CATEGORY" == "t2i" ]; then
        echo -e "${BLUE}[Text to Image]${NC}"
        mkdir -p "$TARGET_DIR/Text to Image"

        for workflow_file in "$T2I_DIR"/*.json; do
            if [ -f "$workflow_file" ]; then
                filename=$(basename "$workflow_file")
                echo -e "  ${GREEN}+${NC} $filename"
                cp "$workflow_file" "$TARGET_DIR/Text to Image/"
                chmod 644 "$TARGET_DIR/Text to Image/$filename"
                copied_count=$((copied_count + 1))
            fi
        done
    else
        t2i_count=$(find "$T2I_DIR" -name "*.json" -type f | wc -l | tr -d ' ')
        echo -e "${DIM}[Text to Image] Skipped $t2i_count workflows (not needed for $INSTALL_CATEGORY)${NC}"
        skipped_count=$((skipped_count + t2i_count))
    fi
fi

echo ""

# Copy Image to Video workflows
I2V_DIR="$WORKFLOW_DIR/Image to Video"
if [ -d "$I2V_DIR" ]; then
    if [ "$INSTALL_CATEGORY" == "all" ] || [ "$INSTALL_CATEGORY" == "i2v" ]; then
        echo -e "${BLUE}[Image to Video]${NC}"
        mkdir -p "$TARGET_DIR/Image to Video"

        for workflow_file in "$I2V_DIR"/*.json; do
            if [ -f "$workflow_file" ]; then
                filename=$(basename "$workflow_file")
                echo -e "  ${GREEN}+${NC} $filename"
                cp "$workflow_file" "$TARGET_DIR/Image to Video/"
                chmod 644 "$TARGET_DIR/Image to Video/$filename"
                copied_count=$((copied_count + 1))
            fi
        done
    else
        i2v_count=$(find "$I2V_DIR" -name "*.json" -type f | wc -l | tr -d ' ')
        echo -e "${DIM}[Image to Video] Skipped $i2v_count workflows (not needed for $INSTALL_CATEGORY)${NC}"
        skipped_count=$((skipped_count + i2v_count))
    fi
fi

echo ""
echo -e "${GREEN}Copied $copied_count workflows, skipped $skipped_count${NC}"

# Try to notify ComfyUI about new workflows via API (if running)
if command -v curl &> /dev/null; then
    echo -e "\n${YELLOW}Checking if ComfyUI API is accessible...${NC}"

    if curl -s "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ComfyUI API is accessible${NC}"
        echo -e "Workflows will be available immediately"
    else
        echo -e "${YELLOW}ComfyUI API not accessible on port $COMFYUI_PORT${NC}"
        echo -e "Workflows will be available after ComfyUI restart or refresh"
    fi
fi

# Create a symlink for easy access (optional)
SYMLINK_PATH="$COMFYUI_DIR/vexa_workflows"
if [ ! -L "$SYMLINK_PATH" ]; then
    ln -s "$TARGET_DIR" "$SYMLINK_PATH" 2>/dev/null || true
fi

# Summary
echo -e "\n${GREEN}=== Workflow Injection Complete ===${NC}"
echo -e "Workflows available in: $TARGET_DIR"
echo -e "\nIn ComfyUI UI:"
echo -e "  1. Click 'Load' button"
echo -e "  2. Navigate to 'Text to Image' or 'Image to Video' folder"

# List installed workflows
echo -e "\n${BLUE}Workflows installed:${NC}"
if [ "$INSTALL_CATEGORY" == "all" ] || [ "$INSTALL_CATEGORY" == "t2i" ]; then
    echo -e "\n  ${YELLOW}Text to Image:${NC}"
    for f in "$TARGET_DIR/Text to Image"/*.json 2>/dev/null; do
        [ -f "$f" ] && echo -e "    - $(basename "$f" .json)"
    done
fi
if [ "$INSTALL_CATEGORY" == "all" ] || [ "$INSTALL_CATEGORY" == "i2v" ]; then
    echo -e "\n  ${YELLOW}Image to Video:${NC}"
    for f in "$TARGET_DIR/Image to Video"/*.json 2>/dev/null; do
        [ -f "$f" ] && echo -e "    - $(basename "$f" .json)"
    done
fi
