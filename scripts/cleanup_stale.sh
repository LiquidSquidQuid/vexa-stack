#!/bin/bash

# Cleanup stale models and workflows that are no longer in manifest
# Run this to remove old files from previous installations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Symbols
CHECK="✓"
CROSS="✗"
TRASH="🗑"
FOLDER="📁"

# Default values
COMFYUI_DIR=""
DRY_RUN=false
FORCE=false
CLEAN_MODELS=true
CLEAN_WORKFLOWS=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/../configs/model_manifest.json"
WORKFLOWS_SOURCE="$SCRIPT_DIR/../workflows"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --models)
            CLEAN_WORKFLOWS=false
            shift
            ;;
        --workflows)
            CLEAN_MODELS=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [COMFYUI_DIR] [OPTIONS]"
            echo ""
            echo "Clean up stale models and workflows not in manifest"
            echo ""
            echo "Options:"
            echo "  --dry-run     Preview deletions without removing files"
            echo "  --force       Skip confirmation prompts"
            echo "  --models      Clean only models (skip workflows)"
            echo "  --workflows   Clean only workflows (skip models)"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 /workspace/ComfyUI --dry-run"
            echo "  $0 /workspace/ComfyUI --force"
            exit 0
            ;;
        *)
            if [ -z "$COMFYUI_DIR" ]; then
                COMFYUI_DIR="$1"
            fi
            shift
            ;;
    esac
done

# Default ComfyUI directory
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"

# Verify directories exist
if [ ! -d "$COMFYUI_DIR" ]; then
    echo -e "${RED}Error: ComfyUI directory not found: $COMFYUI_DIR${NC}"
    exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}Error: Manifest file not found: $MANIFEST_FILE${NC}"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq...${NC}"
    apt-get update -qq && apt-get install -y -qq jq 2>/dev/null || {
        echo -e "${RED}Error: jq is required but could not be installed${NC}"
        exit 1
    }
fi

# Print header
echo ""
echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║           VEXA STACK - STALE FILE CLEANUP                     ║${NC}"
echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${FOLDER} ComfyUI: ${CYAN}$COMFYUI_DIR${NC}"
echo -e "  📋 Manifest: ${CYAN}$MANIFEST_FILE${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}⚠ DRY RUN MODE - No files will be deleted${NC}"
fi
echo ""

# Arrays for tracking
declare -a STALE_MODELS=()
declare -a STALE_WORKFLOWS=()
TOTAL_SIZE=0

# Function to get human-readable size
human_size() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc)GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc)MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Function to get file size in bytes
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Build list of expected model filenames from manifest
get_manifest_models() {
    jq -r '.models[] | .name' "$MANIFEST_FILE" 2>/dev/null | sort -u
}

# Model type to directory mapping
get_model_dir() {
    local type="$1"
    case "$type" in
        checkpoint) echo "models/checkpoints" ;;
        lora) echo "models/loras" ;;
        vae) echo "models/vae" ;;
        embedding) echo "models/embeddings" ;;
        upscale) echo "models/upscale_models" ;;
        controlnet) echo "models/controlnet" ;;
        diffusion_model) echo "models/diffusion_models" ;;
        text_encoder) echo "models/text_encoders" ;;
        clip_vision) echo "models/clip_vision" ;;
        motion_model) echo "models/animatediff_models" ;;
        sams) echo "models/sams" ;;
        ultralytics_bbox) echo "models/ultralytics/bbox" ;;
        ultralytics_segm) echo "models/ultralytics/segm" ;;
        insightface) echo "models/insightface" ;;
        facerestore) echo "models/facerestore_models" ;;
        *) echo "models/$type" ;;
    esac
}

# Scan for stale models
scan_stale_models() {
    echo -e "${BOLD}Scanning for stale models...${NC}\n"

    # Get all expected model names
    local manifest_models=$(get_manifest_models)

    # Directories to scan
    local model_dirs=(
        "models/checkpoints"
        "models/loras"
        "models/vae"
        "models/embeddings"
        "models/upscale_models"
        "models/controlnet"
        "models/diffusion_models"
        "models/text_encoders"
        "models/clip_vision"
        "models/animatediff_models"
        "models/sams"
        "models/ultralytics/bbox"
        "models/ultralytics/segm"
        "models/insightface"
        "models/facerestore_models"
    )

    local stale_count=0

    for rel_dir in "${model_dirs[@]}"; do
        local full_dir="$COMFYUI_DIR/$rel_dir"

        if [ ! -d "$full_dir" ]; then
            continue
        fi

        # Find all model files in this directory
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")

            # Check if this file is in the manifest
            if ! echo "$manifest_models" | grep -qxF "$filename"; then
                local size=$(get_file_size "$file")
                STALE_MODELS+=("$file|$size")
                TOTAL_SIZE=$((TOTAL_SIZE + size))
                stale_count=$((stale_count + 1))

                echo -e "  ${TRASH} ${DIM}$rel_dir/${NC}${RED}$filename${NC} ${DIM}($(human_size $size))${NC}"
            fi
        done < <(find "$full_dir" -maxdepth 1 -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth" -o -name "*.pt" -o -name "*.onnx" -o -name "*.bin" -o -name "*.gguf" \) -print0 2>/dev/null)
    done

    if [ $stale_count -eq 0 ]; then
        echo -e "  ${GREEN}${CHECK} No stale models found${NC}"
    else
        echo ""
        echo -e "  ${YELLOW}Found $stale_count stale model(s)${NC}"
    fi
    echo ""
}

# Scan for stale workflows
scan_stale_workflows() {
    echo -e "${BOLD}Scanning for stale workflows...${NC}\n"

    # Common workflow target locations
    local workflow_targets=(
        "$COMFYUI_DIR/user/default/workflows"
        "$COMFYUI_DIR/workflows"
    )

    local stale_count=0

    for target_dir in "${workflow_targets[@]}"; do
        if [ ! -d "$target_dir" ]; then
            continue
        fi

        # Get list of source workflows (flatten structure)
        local source_workflows=$(find "$WORKFLOWS_SOURCE" -name "*.json" -type f -exec basename {} \; 2>/dev/null | sort -u)

        # Check each file in target
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")

            # Skip if file exists in source
            if echo "$source_workflows" | grep -qxF "$filename"; then
                continue
            fi

            # Skip files that don't look like vexa workflows (user's own workflows)
            # We only clean workflows that match known deleted patterns
            case "$filename" in
                "AI_Influencer_CausVid_ReActor.json"|\
                "Basic Wan 2_1.json"|\
                "Black Mixture"*|\
                "FINAL Image to Video.json"|\
                "Hunyuan-img2vid.json"|\
                "image to video.json"|\
                "image_to_video_wan_example.json"|\
                "Wan22_"*|\
                "wan22_"*|\
                "wan21LowVramComfyUI 2.json")
                    local size=$(get_file_size "$file")
                    STALE_WORKFLOWS+=("$file|$size")
                    TOTAL_SIZE=$((TOTAL_SIZE + size))
                    stale_count=$((stale_count + 1))

                    echo -e "  ${TRASH} ${RED}$filename${NC}"
                    ;;
            esac
        done < <(find "$target_dir" -maxdepth 2 -name "*.json" -type f -print0 2>/dev/null)
    done

    if [ $stale_count -eq 0 ]; then
        echo -e "  ${GREEN}${CHECK} No stale workflows found${NC}"
    else
        echo ""
        echo -e "  ${YELLOW}Found $stale_count stale workflow(s)${NC}"
    fi
    echo ""
}

# Delete stale files
cleanup_files() {
    local total_files=$((${#STALE_MODELS[@]} + ${#STALE_WORKFLOWS[@]}))

    if [ $total_files -eq 0 ]; then
        echo -e "${GREEN}Nothing to clean up!${NC}"
        return 0
    fi

    echo -e "${BOLD}┌─────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│         CLEANUP SUMMARY             │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│${NC} Stale models:    ${RED}${#STALE_MODELS[@]}${NC} files          ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} Stale workflows: ${RED}${#STALE_WORKFLOWS[@]}${NC} files          ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} Total size:      ${YELLOW}$(human_size $TOTAL_SIZE)${NC}          ${BOLD}│${NC}"
    echo -e "${BOLD}└─────────────────────────────────────┘${NC}"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN - No files were deleted${NC}"
        echo -e "${DIM}Run without --dry-run to delete these files${NC}"
        return 0
    fi

    # Confirm unless --force
    if [ "$FORCE" != true ]; then
        echo -e "${YELLOW}This will permanently delete the files listed above.${NC}"
        read -p "Are you sure you want to proceed? [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Cleanup cancelled.${NC}"
            return 0
        fi
    fi

    echo ""
    echo -e "${BOLD}Deleting stale files...${NC}"

    local deleted=0
    local failed=0

    # Delete stale models
    for item in "${STALE_MODELS[@]}"; do
        IFS='|' read -r file size <<< "$item"
        if rm -f "$file" 2>/dev/null; then
            echo -e "  ${GREEN}${CHECK}${NC} Deleted: $(basename "$file")"
            deleted=$((deleted + 1))
        else
            echo -e "  ${RED}${CROSS}${NC} Failed: $(basename "$file")"
            failed=$((failed + 1))
        fi
    done

    # Delete stale workflows
    for item in "${STALE_WORKFLOWS[@]}"; do
        IFS='|' read -r file size <<< "$item"
        if rm -f "$file" 2>/dev/null; then
            echo -e "  ${GREEN}${CHECK}${NC} Deleted: $(basename "$file")"
            deleted=$((deleted + 1))
        else
            echo -e "  ${RED}${CROSS}${NC} Failed: $(basename "$file")"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo -e "${BOLD}Cleanup complete!${NC}"
    echo -e "  ${GREEN}Deleted: $deleted files${NC}"
    if [ $failed -gt 0 ]; then
        echo -e "  ${RED}Failed: $failed files${NC}"
    fi
    echo -e "  ${CYAN}Space recovered: $(human_size $TOTAL_SIZE)${NC}"
}

# Main execution
if [ "$CLEAN_MODELS" = true ]; then
    scan_stale_models
fi

if [ "$CLEAN_WORKFLOWS" = true ]; then
    scan_stale_workflows
fi

cleanup_files

echo ""
