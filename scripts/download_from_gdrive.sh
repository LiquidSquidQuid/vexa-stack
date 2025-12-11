#!/bin/bash

# Google Drive Model Sync for ComfyUI
# Automatically downloads ALL files from Drive folder and sorts them intelligently

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
# Allow override via environment variable, with default fallback
DRIVE_FOLDER_ID="${GDRIVE_FOLDER_ID:-1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L}"

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

    # CLIP Vision patterns (must be before general clip)
    if [[ "$filename_lower" == *"clip_vision"* ]]; then
        echo "$COMFYUI_DIR/models/clip_vision"
        return
    fi

    # Diffusion model patterns (Wan I2V, etc.)
    if [[ "$filename_lower" == *"diffusion"* ]] || [[ "$filename_lower" == *"i2v"* ]] || [[ "$filename_lower" == *"wan"* ]] || [[ "$filename_lower" == *"unet"* ]]; then
        echo "$COMFYUI_DIR/models/diffusion_models"
        return
    fi

    # Text encoder patterns (UMT5, T5, etc.)
    if [[ "$filename_lower" == *"umt5"* ]] || [[ "$filename_lower" == *"t5xxl"* ]] || [[ "$filename_lower" == *"text_encoder"* ]]; then
        echo "$COMFYUI_DIR/models/text_encoders"
        return
    fi

    # General CLIP patterns
    if [[ "$filename_lower" == *"clip"* ]]; then
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
        *"/clip_vision"*) echo "CLIP Vision" ;;
        *"/clip"*) echo "CLIP" ;;
        *"/diffusion_models"*) echo "Diffusion Model" ;;
        *"/text_encoders"*) echo "Text Encoder" ;;
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

# Get list of files in folder
get_folder_file_list() {
    # Use gdown to list folder contents and extract file IDs and names
    gdown --folder --id "$DRIVE_FOLDER_ID" --dry-run 2>&1 | grep "Processing file" | while read -r line; do
        # Extract file ID and name from "Processing file <id> <name>"
        file_id=$(echo "$line" | awk '{print $3}')
        file_name=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ ]*//')
        echo "$file_id|$file_name"
    done
}

# Download single file with retry
download_single_file() {
    local file_id="$1"
    local file_name="$2"
    local dest_dir="$3"
    local attempt=1
    local delay=$RETRY_DELAY

    local dest_path="$dest_dir/$file_name"

    # Check if already exists
    if [ -f "$dest_path" ] && [ -s "$dest_path" ]; then
        local size=$(stat -c%s "$dest_path" 2>/dev/null || stat -f%z "$dest_path" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000 ]; then
            echo -e "  ${DIM}○ ${file_name} - already exists, skipping${NC}"
            return 0
        fi
    fi

    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "  ${CYAN}${DOWNLOAD}${NC} ${file_name} ${DIM}(attempt $attempt/$MAX_RETRIES)${NC}"

        # Try to download the file
        if gdown --id "$file_id" -O "$dest_path" 2>&1; then
            # Verify download succeeded
            if [ -f "$dest_path" ] && [ -s "$dest_path" ]; then
                echo -e "  ${GREEN}${CHECK}${NC} ${file_name} downloaded successfully"
                return 0
            fi
        fi

        # Check if rate limited and retry
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo -e "  ${YELLOW}Rate limited. Waiting ${delay}s before retry...${NC}"
            sleep $delay
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    echo -e "  ${RED}${CROSS}${NC} ${file_name} - failed after $MAX_RETRIES attempts"
    echo -e "      ${DIM}Manual download: https://drive.google.com/uc?id=${file_id}${NC}"
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

    # Get file list from folder
    print_header "SCANNING GOOGLE DRIVE FOLDER"

    echo -e "${YELLOW}Fetching file list from Google Drive...${NC}"
    echo ""

    # Get list of files with error handling for gdown output format changes
    local raw_output=$(gdown --folder --id "$DRIVE_FOLDER_ID" --dry-run 2>&1 || true)
    local file_list=$(echo "$raw_output" | grep "Processing file" || true)

    if [ -z "$file_list" ]; then
        echo -e "${RED}${CROSS} Could not retrieve file list from Google Drive${NC}"
        echo -e "${YELLOW}This might be due to:${NC}"
        echo -e "  - Folder sharing permissions"
        echo -e "  - Network issues"
        echo -e "  - gdown output format change"
        echo ""
        echo -e "${DIM}Raw output (for debugging):${NC}"
        echo -e "${DIM}$(echo "$raw_output" | head -5)${NC}"
        echo ""
        echo -e "Make sure the folder is shared as 'Anyone with the link can view'"
        echo -e "Or set GDRIVE_FOLDER_ID environment variable to use a different folder"
        return 1
    fi

    # Parse and display files
    echo -e "${BOLD}Files found in Google Drive:${NC}\n"

    local total_files=0
    local success_count=0
    local skip_count=0
    local fail_count=0

    # Store file info for processing
    declare -a files_to_process

    while IFS= read -r line; do
        if [[ "$line" == *"Processing file"* ]]; then
            file_id=$(echo "$line" | awk '{print $3}')
            file_name=$(echo "$line" | sed 's/Processing file [^ ]* //')

            # Determine destination
            dest_dir=$(get_destination_dir "$file_name")
            type_name=$(get_type_name "$dest_dir")

            echo -e "  ${BLUE}${CLOUD}${NC} ${file_name}"
            echo -e "      ${ARROW} ${type_name}"

            files_to_process+=("$file_id|$file_name|$dest_dir|$type_name")
            total_files=$((total_files + 1))
        fi
    done <<< "$file_list"

    echo ""
    echo -e "${BOLD}Total files to process: ${total_files}${NC}"

    # Download files individually
    print_header "DOWNLOADING FILES"

    local current=0
    for file_info in "${files_to_process[@]}"; do
        IFS='|' read -r file_id file_name dest_dir type_name <<< "$file_info"
        current=$((current + 1))

        echo -e "\n${BOLD}[${current}/${total_files}]${NC} ${file_name} ${DIM}(${type_name})${NC}"

        # Create destination directory
        mkdir -p "$dest_dir"

        # Download the file
        if download_single_file "$file_id" "$file_name" "$dest_dir"; then
            success_count=$((success_count + 1))
        else
            # Check if it was skipped (already exists)
            if [ -f "$dest_dir/$file_name" ] && [ -s "$dest_dir/$file_name" ]; then
                skip_count=$((skip_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        fi
    done

    # Final summary
    print_header "SYNC COMPLETE"

    echo -e "${BOLD}Download Summary:${NC}"
    echo -e "  ${GREEN}${CHECK} Downloaded:${NC} ${success_count} files"
    echo -e "  ${DIM}○ Skipped:${NC} ${skip_count} files (already exist)"
    if [ $fail_count -gt 0 ]; then
        echo -e "  ${RED}${CROSS} Failed:${NC} ${fail_count} files"
    fi

    echo ""
    echo -e "${BOLD}Files in each directory:${NC}"
    for dir in checkpoints loras vae embeddings upscale_models controlnet clip clip_vision diffusion_models text_encoders; do
        full_path="$COMFYUI_DIR/models/$dir"
        if [ -d "$full_path" ]; then
            count=$(find "$full_path" -maxdepth 1 -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" -o -name "*.pth" \) 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                echo -e "  📁 ${dir}: ${GREEN}${count}${NC} files"
            fi
        fi
    done

    echo ""
    if [ $fail_count -gt 0 ]; then
        echo -e "${YELLOW}Some files failed to download due to rate limiting.${NC}"
        echo -e "You can retry later or download manually from:"
        echo -e "  ${CYAN}https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID${NC}"
    else
        echo -e "${GREEN}${CHECK} Google Drive sync complete!${NC}"
    fi
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
