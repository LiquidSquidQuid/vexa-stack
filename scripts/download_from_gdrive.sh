#!/bin/bash

# Google Drive model download script for ComfyUI
# Downloads models from your Google Drive folder to ComfyUI

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
DRIVE_FOLDER_ID="${2:-1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L}"  # Your Drive folder

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Google Drive Model Downloader ===${NC}"
echo -e "Drive Folder: https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID"

# Install gdown if not present
install_gdown() {
    if ! command -v gdown &> /dev/null; then
        echo -e "${YELLOW}Installing gdown...${NC}"
        pip install --upgrade --no-cache-dir gdown -q || {
            echo -e "${RED}Failed to install gdown${NC}"
            echo "Try: pip install gdown"
            exit 1
        }
    fi
    echo -e "${GREEN}✓ gdown is installed${NC}"
}

# Download file from Google Drive
download_from_drive() {
    local file_id="$1"
    local output_path="$2"
    local file_name="$3"
    
    echo -e "${BLUE}Downloading: $file_name${NC}"
    
    # Check if file already exists
    if [ -f "$output_path" ] && [ -s "$output_path" ]; then
        echo -e "${GREEN}  ✓ Already exists: $file_name${NC}"
        return 0
    fi
    
    # Create directory if needed
    mkdir -p "$(dirname "$output_path")"
    
    # Download with gdown
    if [ -n "$file_id" ]; then
        # Direct file download
        echo -e "  Downloading from file ID: $file_id"
        gdown --id "$file_id" -O "$output_path" --quiet || {
            echo -e "${RED}  ✗ Failed to download: $file_name${NC}"
            return 1
        }
    else
        # Try fuzzy matching by name
        echo -e "  Searching in Drive folder for: $file_name"
        gdown --folder --id "$DRIVE_FOLDER_ID" -O "$(dirname "$output_path")" --quiet || {
            echo -e "${RED}  ✗ Failed to download from folder${NC}"
            return 1
        }
    fi
    
    if [ -f "$output_path" ]; then
        echo -e "${GREEN}  ✓ Downloaded: $file_name${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Download failed: $file_name${NC}"
        return 1
    fi
}

# Download entire folder
download_folder() {
    local folder_id="$1"
    local output_dir="$2"
    
    echo -e "${YELLOW}Downloading entire folder...${NC}"
    mkdir -p "$output_dir"
    
    # Use gdown to download folder
    gdown --folder --id "$folder_id" -O "$output_dir" || {
        echo -e "${RED}Failed to download folder${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ Folder downloaded${NC}"
}

# Main download function
download_models() {
    # Install gdown first
    install_gdown
    
    # Model configurations
    # Format: "file_id|output_path|name"
    local models=(
        # Checkpoints - update these with actual file IDs from your Drive
        "|$COMFYUI_DIR/models/checkpoints/ponyRealism_v22MainVAE.safetensors|Pony Realism v2.2"
        "|$COMFYUI_DIR/models/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors|RealVisXL V5"
        
        # LoRAs
        "|$COMFYUI_DIR/models/loras/detail_enhancer_xl.safetensors|Detail Enhancer XL"
        "|$COMFYUI_DIR/models/loras/add-detail-xl.safetensors|Add Detail XL"
        
        # VAE
        "|$COMFYUI_DIR/models/vae/sdxl_vae.safetensors|SDXL VAE"
    )
    
    echo -e "\n${YELLOW}Downloading models from Google Drive...${NC}"
    
    local success=0
    local failed=0
    
    for model_config in "${models[@]}"; do
        IFS='|' read -r file_id output_path name <<< "$model_config"
        
        if download_from_drive "$file_id" "$output_path" "$name"; then
            ((success++))
        else
            ((failed++))
        fi
        echo ""
    done
    
    # Summary
    echo -e "${GREEN}=== Download Summary ===${NC}"
    echo -e "Successfully downloaded: $success models"
    if [ $failed -gt 0 ]; then
        echo -e "${YELLOW}Failed downloads: $failed models${NC}"
        echo -e "\nTo manually download models:"
        echo -e "1. Upload them to: https://drive.google.com/drive/folders/$DRIVE_FOLDER_ID"
        echo -e "2. Get the file ID (right-click → Get link → extract ID)"
        echo -e "3. Update this script with the file IDs"
    fi
}

# Alternative: Download all from folder
download_all_from_folder() {
    echo -e "${YELLOW}Downloading all models from Drive folder...${NC}"
    
    # Create temp directory
    local temp_dir="/tmp/gdrive_models"
    mkdir -p "$temp_dir"
    
    # Download entire folder
    gdown --folder --id "$DRIVE_FOLDER_ID" -O "$temp_dir" || {
        echo -e "${RED}Failed to download folder${NC}"
        return 1
    }
    
    # Move files to appropriate directories
    echo -e "${YELLOW}Organizing downloaded models...${NC}"
    
    # Move checkpoints
    find "$temp_dir" -name "*.safetensors" -o -name "*.ckpt" | while read -r file; do
        filename=$(basename "$file")
        
        # Determine destination based on filename patterns
        if [[ "$filename" == *"lora"* ]] || [[ "$filename" == *"LoRA"* ]]; then
            mv "$file" "$COMFYUI_DIR/models/loras/" 2>/dev/null || true
            echo "  Moved to LoRAs: $filename"
        elif [[ "$filename" == *"vae"* ]] || [[ "$filename" == *"VAE"* ]]; then
            mv "$file" "$COMFYUI_DIR/models/vae/" 2>/dev/null || true
            echo "  Moved to VAE: $filename"
        else
            mv "$file" "$COMFYUI_DIR/models/checkpoints/" 2>/dev/null || true
            echo "  Moved to checkpoints: $filename"
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    echo -e "${GREEN}✓ Models organized${NC}"
}

# Help function
show_help() {
    echo "Usage: $0 [COMFYUI_DIR] [DRIVE_FOLDER_ID]"
    echo ""
    echo "Downloads models from Google Drive to ComfyUI"
    echo ""
    echo "Options:"
    echo "  COMFYUI_DIR     Path to ComfyUI (default: /workspace/ComfyUI)"
    echo "  DRIVE_FOLDER_ID Google Drive folder ID (default: your folder)"
    echo ""
    echo "Commands:"
    echo "  --all           Download entire folder"
    echo "  --help          Show this help"
}

# Main execution
if [ "$1" == "--help" ]; then
    show_help
    exit 0
elif [ "$1" == "--all" ]; then
    download_all_from_folder
else
    download_models
fi

echo -e "\n${GREEN}=== Google Drive Download Complete ===${NC}"
echo -e "Models location: $COMFYUI_DIR/models/"