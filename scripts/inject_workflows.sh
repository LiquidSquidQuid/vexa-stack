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
NC='\033[0m'

echo -e "${GREEN}=== Workflow Injection for ComfyUI ===${NC}"

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

echo -e "${BLUE}Found $workflow_count workflow(s) to inject${NC}"

# Determine target directory for workflows
# ComfyUI stores workflows in different locations depending on setup
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
    TARGET_DIR="$COMFYUI_DIR/workflows"
    echo -e "${YELLOW}Creating workflow directory: $TARGET_DIR${NC}"
fi

mkdir -p "$TARGET_DIR"

# Copy workflow files
echo -e "\n${YELLOW}Copying workflows to: $TARGET_DIR${NC}"
for workflow_file in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
        filename=$(basename "$workflow_file")
        echo -e "  Copying: $filename"
        cp "$workflow_file" "$TARGET_DIR/"
        
        # Make the file readable by ComfyUI
        chmod 644 "$TARGET_DIR/$filename"
    fi
done

# Try to notify ComfyUI about new workflows via API (if running)
if command -v curl &> /dev/null; then
    echo -e "\n${YELLOW}Checking if ComfyUI API is accessible...${NC}"
    
    if curl -s "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ComfyUI API is accessible${NC}"
        
        # Optional: Upload workflows via API for immediate availability
        for workflow_file in "$WORKFLOW_DIR"/*.json; do
            if [ -f "$workflow_file" ]; then
                filename=$(basename "$workflow_file")
                echo -e "  Registering via API: $filename"
                
                # Note: ComfyUI doesn't have a direct workflow upload API
                # but this is where you could add it if available
            fi
        done
    else
        echo -e "${YELLOW}ComfyUI API not accessible on port $COMFYUI_PORT${NC}"
        echo -e "Workflows will be available after ComfyUI restart or refresh"
    fi
fi

# Create a symlink for easy access (optional)
SYMLINK_PATH="$COMFYUI_DIR/vexa_workflows"
if [ ! -L "$SYMLINK_PATH" ]; then
    ln -s "$TARGET_DIR" "$SYMLINK_PATH" 2>/dev/null || true
    echo -e "\n${GREEN}Created symlink: $SYMLINK_PATH${NC}"
fi

# Summary
echo -e "\n${GREEN}=== Workflow Injection Complete ===${NC}"
echo -e "Workflows available in: $TARGET_DIR"
echo -e "\nIn ComfyUI UI:"
echo -e "  1. Click 'Load' button"
echo -e "  2. Look for workflows starting with 'vexa_'"
echo -e "\nWorkflows injected:"
for workflow_file in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
        filename=$(basename "$workflow_file" .json)
        echo -e "  - $filename"
    fi
done