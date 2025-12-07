#!/bin/bash

# Google Drive Model Sync for ComfyUI
# Automatically downloads ALL files from Drive folder and sorts them intelligently

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
DRIVE_FOLDER_ID="1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L"

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CHECK="✓"
CROSS="✗"
CLOUD="☁"
ARROW="→"
DOWNLOAD="⬇"

# Retry settings
MAX_RETRIES=3
RETRY_DELAY=30

# Print header
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Determine destination directory based on filename
get_destination_dir() {
    local filename="$1"
    local filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

    # LoRA patterns
    if [[ "$filename_lower" == *"lora"* ]] || [[ "$filename_lower" == *"_lo_"* ]]; then
        echo "$COMFYUI_DIR/models/loras"
        return
    fi

    # VAE patterns
    if [[ "$filename_lower" == *"vae"* ]]; then
        echo "$COMFYUI_DIR/models/vae"
        return
    fi

    # Embedding patterns
    if [[ "$filename_lower" == *"embedding"* ]] || [[ "$filename_lower" == *"embed"* ]] || [[ "$filename_lower" == *"textual_inversion"* ]]; then
        echo "$COMFYUI_DIR/models/embeddings"
        return
    fi

    # Upscaler patterns
    if [[ "$filename_lower" == *"upscale"* ]] || [[ "$filename_lower" == *"esrgan"* ]] || [[ "$filename_lower" == *"4x"* ]] || [[ "$filename_lower" == *"2x"* ]]; then
        echo "$COMFYUI_DIR/models/upscale_models"
        return
    fi

    # ControlNet patterns
    if [[ "$filename_lower" == *"controlnet"* ]] || [[ "$filename_lower" == *"control_"* ]] || [[ "$filename_lower" == *"cn_"* ]]; then
        echo "$COMFYUI_DIR/models/controlnet"
        return
    fi

    # CLIP patterns
    if [[ "$filename_lower" == *"clip"* ]] || [[ "$filename_lower" == *"text_encoder"* ]]; then
        echo "$COMFYUI_DIR/models/clip"
        return
    fi

    # Workflow JSON files
    if [[ "$filename" == *.json ]]; then
        echo "$COMFYUI_DIR/user/default/workflows"
        return
    fi

    # Default: checkpoints for .safetensors and .ckpt
    if [[ "$filename" == *.safetensors ]] || [[ "$filename" == *.ckpt ]]; then
        echo "$COMFYUI_DIR/models/checkpoints"
        return
    fi

    # Other files go to a misc folder
    echo "$COMFYUI_DIR/models/other"
}

# Get friendly type name for display
get_type_name() {
    local dest_dir="$1"
    case "$dest_dir" in
        *"/loras"*) echo "LoRA" ;;
        *"/vae"*) echo "VAE" ;;
        *"/embeddings"*) echo "Embedding" ;;
        *"/upscale_models"*) echo "Upscaler" ;;
        *"/controlnet"*) echo "ControlNet" ;;
        *"/clip"*) echo "CLIP" ;;
        *"/workflows"*) echo "Workflow" ;;
        *"/checkpoints"*) echo "Checkpoint" ;;
        *) echo "Other" ;;
    esac
}

# Install gdown if needed
install_gdown() {
    if ! command -v gdown &> /dev/null; then
        echo -e "${YELLOW}Installing gdown...${NC}"
        pip install --upgrade --no-cache-dir gdown -q 2>/dev/null || {
            echo -e "${RED}Failed to install gdown${NC}"
            echo "Try: pip install gdown"
            return 1
        }
    fi
    echo -e "${GREEN}${CHECK} gdown is ready${NC}"
    return 0
}

# Download with retry logic
download_with_retry() {
    local attempt=1
    local temp_dir="$1"

    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "${CYAN}${DOWNLOAD} Download attempt $attempt of $MAX_RETRIES...${NC}"

        # Try to download the folder
        if gdown --folder --id "$DRIVE_FOLDER_ID" -O "$temp_dir" 2>&1; then
            return 0
        fi

        # Check if it's a rate limit error
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Download may have been rate-limited. Waiting ${RETRY_DELAY}s before retry...${NC}"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# Main sync function
sync_from_gdrive() {
    print_header "GOOGLE DRIVE MODEL SYNC"

    echo -e "  ${CLOUD} Drive Folder: ${CYAN}https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID${NC}"
    echo -e "  📁 Target: ${CYAN}$COMFYUI_DIR${NC}"
    echo ""

    # Install gdown
    install_gdown || return 1

    # Create temp directory
    local temp_dir="/tmp/gdrive_sync_$$"
    mkdir -p "$temp_dir"

    # Download folder contents
    print_header "DOWNLOADING FROM GOOGLE DRIVE"

    echo -e "${YELLOW}Fetching file list from Google Drive...${NC}"
    echo -e "${DIM}(This may take a moment for large folders)${NC}"
    echo ""

    if ! download_with_retry "$temp_dir"; then
        echo -e "${RED}${CROSS} Failed to download from Google Drive after $MAX_RETRIES attempts${NC}"
        echo -e "${YELLOW}This might be due to:${NC}"
        echo -e "  - Too many recent downloads (rate limiting)"
        echo -e "  - Network issues"
        echo -e "  - Folder sharing permissions"
        echo ""
        echo -e "Try again later or download manually from:"
        echo -e "  ${CYAN}https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID${NC}"
        rm -rf "$temp_dir"
        return 1
    fi

    # Process downloaded files
    print_header "SORTING DOWNLOADED FILES"

    # Count files by type
    local checkpoint_count=0
    local lora_count=0
    local vae_count=0
    local other_count=0
    local total_count=0
    local skipped_count=0

    # Find all downloaded files
    echo -e "${BOLD}Processing downloaded files...${NC}\n"

    find "$temp_dir" -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" -o -name "*.pth" -o -name "*.json" \) | while read -r file; do
        filename=$(basename "$file")
        dest_dir=$(get_destination_dir "$filename")
        type_name=$(get_type_name "$dest_dir")
        dest_path="$dest_dir/$filename"

        # Create destination directory
        mkdir -p "$dest_dir"

        # Check if file already exists
        if [ -f "$dest_path" ]; then
            local existing_size=$(stat -c%s "$dest_path" 2>/dev/null || stat -f%z "$dest_path" 2>/dev/null || echo "0")
            local new_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")

            if [ "$existing_size" -eq "$new_size" ]; then
                echo -e "  ${DIM}○ ${filename} [${type_name}] - already exists, skipping${NC}"
                continue
            fi
        fi

        # Move file to destination
        echo -e "  ${GREEN}${CHECK}${NC} ${filename}"
        echo -e "      ${ARROW} ${type_name}: ${DIM}${dest_dir}${NC}"
        mv "$file" "$dest_path"

    done

    # Cleanup
    rm -rf "$temp_dir"

    # Final summary
    print_header "SYNC COMPLETE"

    echo -e "${BOLD}Files in each directory:${NC}"
    for dir in checkpoints loras vae embeddings upscale_models controlnet clip; do
        full_path="$COMFYUI_DIR/models/$dir"
        if [ -d "$full_path" ]; then
            count=$(find "$full_path" -maxdepth 1 -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" -o -name "*.pth" \) 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                echo -e "  📁 ${dir}: ${GREEN}${count}${NC} files"
            fi
        fi
    done

    echo ""
    echo -e "${GREEN}${CHECK} Google Drive sync complete!${NC}"
}

# Show help
show_help() {
    echo "Google Drive Model Sync for ComfyUI"
    echo ""
    echo "Usage: $0 [COMFYUI_DIR]"
    echo ""
    echo "Downloads all models from your Google Drive folder and"
    echo "automatically sorts them into the correct ComfyUI directories."
    echo ""
    echo "Arguments:"
    echo "  COMFYUI_DIR   Path to ComfyUI (default: /workspace/ComfyUI)"
    echo ""
    echo "File Routing:"
    echo "  *lora*, *LoRA*           → models/loras/"
    echo "  *vae*, *VAE*             → models/vae/"
    echo "  *embedding*, *embed*     → models/embeddings/"
    echo "  *upscale*, *ESRGAN*      → models/upscale_models/"
    echo "  *controlnet*, *cn_*      → models/controlnet/"
    echo "  *.safetensors, *.ckpt    → models/checkpoints/ (default)"
    echo ""
    echo "Google Drive Folder:"
    echo "  https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID"
}

# Main execution
case "$1" in
    --help|-h)
        show_help
        ;;
    *)
        sync_from_gdrive
        ;;
esac
