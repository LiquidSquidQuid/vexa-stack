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

# Copy workflow files (including subdirectories)
echo -e "\n${YELLOW}Copying workflows to: $TARGET_DIR${NC}"

# Track counts
copied_count=0
skipped_count=0

# Copy root-level JSON files (always copy vexa_ prefixed ones, filter others by category)
for workflow_file in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
        filename=$(basename "$workflow_file")
        filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

        # Determine if this is T2I or I2V workflow based on name
        is_i2v=false
        if [[ "$filename_lower" == *"video"* ]] || [[ "$filename_lower" == *"i2v"* ]] || \
           [[ "$filename_lower" == *"wan"* ]] || [[ "$filename_lower" == *"hunyuan"* ]]; then
            is_i2v=true
        fi

        # Filter based on category
        should_copy=true
        if [ "$INSTALL_CATEGORY" == "t2i" ] && [ "$is_i2v" == true ]; then
            should_copy=false
        elif [ "$INSTALL_CATEGORY" == "i2v" ] && [ "$is_i2v" == false ]; then
            # For I2V mode, skip T2I-only workflows (but keep generic ones)
            if [[ "$filename_lower" == *"flux"* ]] || [[ "$filename_lower" == *"aphrodite"* ]] || \
               [[ "$filename_lower" == *"biglove"* ]] || [[ "$filename_lower" == *"dmd2"* ]]; then
                should_copy=false
            fi
        fi

        if [ "$should_copy" == true ]; then
            echo -e "  Copying: $filename"
            cp "$workflow_file" "$TARGET_DIR/"
            chmod 644 "$TARGET_DIR/$filename"
            copied_count=$((copied_count + 1))
        else
            echo -e "  ${YELLOW}Skipping: $filename (not needed for $INSTALL_CATEGORY)${NC}"
            skipped_count=$((skipped_count + 1))
        fi
    fi
done

# Copy subdirectories based on category
for subdir in "$WORKFLOW_DIR"/*/; do
    if [ -d "$subdir" ]; then
        subdir_name=$(basename "$subdir")
        subdir_lower=$(echo "$subdir_name" | tr '[:upper:]' '[:lower:]')

        # Determine if this directory should be copied based on category
        should_copy_dir=false
        if [ "$INSTALL_CATEGORY" == "all" ]; then
            should_copy_dir=true
        elif [ "$INSTALL_CATEGORY" == "t2i" ] && [[ "$subdir_lower" == *"text"* || "$subdir_lower" == *"image"* && "$subdir_lower" != *"video"* ]]; then
            should_copy_dir=true
        elif [ "$INSTALL_CATEGORY" == "i2v" ] && [[ "$subdir_lower" == *"video"* ]]; then
            should_copy_dir=true
        fi

        if [ "$should_copy_dir" == true ]; then
            echo -e "  Copying subdirectory: $subdir_name/"
            mkdir -p "$TARGET_DIR/$subdir_name"

            for workflow_file in "$subdir"*.json; do
                if [ -f "$workflow_file" ]; then
                    filename=$(basename "$workflow_file")
                    echo -e "    - $filename"
                    cp "$workflow_file" "$TARGET_DIR/$subdir_name/"
                    chmod 644 "$TARGET_DIR/$subdir_name/$filename"
                    copied_count=$((copied_count + 1))
                fi
            done
        else
            echo -e "  ${YELLOW}Skipping subdirectory: $subdir_name/ (not needed for $INSTALL_CATEGORY)${NC}"
        fi
    fi
done

echo -e "\n${GREEN}Copied $copied_count workflows, skipped $skipped_count${NC}"

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
echo -e "  2. Browse workflows or look for 'vexa_' prefixed ones"
echo -e "\nWorkflows injected:"
for workflow_file in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
        filename=$(basename "$workflow_file" .json)
        echo -e "  - $filename"
    fi
done
for subdir in "$WORKFLOW_DIR"/*/; do
    if [ -d "$subdir" ]; then
        subdir_name=$(basename "$subdir")
        echo -e "  [$subdir_name]"
        for workflow_file in "$subdir"*.json; do
            if [ -f "$workflow_file" ]; then
                filename=$(basename "$workflow_file" .json)
                echo -e "    - $filename"
            fi
        done
    fi
done