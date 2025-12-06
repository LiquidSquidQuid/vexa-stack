#!/bin/bash

# Google Drive upload helper for Mac
# Helps you upload ComfyUI models to your Google Drive folder

# Your Google Drive folder
DRIVE_FOLDER_URL="https://drive.google.com/drive/folders/1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Google Drive Model Upload Helper ===${NC}"
echo -e "This script helps you prepare models for upload to Google Drive"
echo -e "Drive folder: $DRIVE_FOLDER_URL\n"

# Find ComfyUI directory on Mac
find_comfyui_mac() {
    local possible_dirs=(
        "$HOME/Documents/ComfyUI"
        "$HOME/ComfyUI"
        "$HOME/Desktop/ComfyUI"
        "$HOME/Downloads/ComfyUI"
        "/Applications/ComfyUI"
    )
    
    for dir in "${possible_dirs[@]}"; do
        if [ -d "$dir/models" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}

# Find models
find_models() {
    local comfyui_dir="$1"
    
    echo -e "${YELLOW}Searching for models...${NC}\n"
    
    echo -e "${BLUE}=== Checkpoints ===${NC}"
    find "$comfyui_dir/models" -type f \( -name "*.safetensors" -o -name "*.ckpt" \) -size +1G 2>/dev/null | while read -r file; do
        local size=$(ls -lh "$file" | awk '{print $5}')
        local name=$(basename "$file")
        echo -e "  $name ${YELLOW}($size)${NC}"
        echo "    Path: $file"
    done
    
    echo -e "\n${BLUE}=== LoRAs ===${NC}"
    find "$comfyui_dir/models/loras" -type f \( -name "*.safetensors" -o -name "*.pt" \) 2>/dev/null | while read -r file; do
        local size=$(ls -lh "$file" | awk '{print $5}')
        local name=$(basename "$file")
        echo -e "  $name ${YELLOW}($size)${NC}"
    done
    
    echo -e "\n${BLUE}=== VAEs ===${NC}"
    find "$comfyui_dir/models/vae" -type f -name "*.safetensors" 2>/dev/null | while read -r file; do
        local size=$(ls -lh "$file" | awk '{print $5}')
        local name=$(basename "$file")
        echo -e "  $name ${YELLOW}($size)${NC}"
    done
}

# Generate upload commands
generate_upload_commands() {
    local comfyui_dir="$1"
    
    echo -e "\n${GREEN}=== Upload Instructions ===${NC}"
    echo -e "1. Open Google Drive in your browser: $DRIVE_FOLDER_URL"
    echo -e "2. Drag and drop these files:\n"
    
    # Priority models for Vexa
    local priority_models=(
        "ponyRealism_v22MainVAE.safetensors"
        "RealVisXL_V5.0_Lightning_fp16.safetensors"
        "sdxl_vae.safetensors"
        "detail_enhancer_xl.safetensors"
    )
    
    echo -e "${YELLOW}Priority models for Vexa:${NC}"
    for model in "${priority_models[@]}"; do
        local file=$(find "$comfyui_dir/models" -name "$model" 2>/dev/null | head -1)
        if [ -f "$file" ]; then
            echo -e "  ✓ $model"
            echo -e "    ${BLUE}$file${NC}"
        else
            echo -e "  ✗ $model ${RED}(not found locally)${NC}"
        fi
    done
}

# Get file IDs after upload
get_file_ids() {
    echo -e "\n${GREEN}=== After Uploading ===${NC}"
    echo -e "To get file IDs for direct downloads:"
    echo -e "1. Right-click the file in Google Drive"
    echo -e "2. Select 'Get link'"
    echo -e "3. The link will look like:"
    echo -e "   https://drive.google.com/file/d/${YELLOW}FILE_ID_HERE${NC}/view"
    echo -e "4. Copy the FILE_ID and update model_manifest.json\n"
    
    echo -e "Example manifest entry:"
    cat << 'EOF'
    {
      "type": "checkpoint",
      "name": "ponyRealism_v22MainVAE.safetensors",
      "url": "gdrive://file",
      "gdrive_id": "PASTE_FILE_ID_HERE",
      "source": "gdrive",
      "size": "6.46GB",
      "required": true
    }
EOF
}

# Install gdrive CLI tool (optional)
install_gdrive_cli() {
    echo -e "\n${YELLOW}=== Optional: Install gdrive CLI ===${NC}"
    echo -e "For command-line uploads, you can install gdrive:"
    echo -e "  ${BLUE}brew install gdrive${NC}"
    echo -e "\nThen upload with:"
    echo -e "  ${BLUE}gdrive upload --parent $DRIVE_FOLDER_URL model.safetensors${NC}"
}

# Main execution
echo -e "${YELLOW}Looking for ComfyUI on your Mac...${NC}"
COMFYUI_DIR=$(find_comfyui_mac)

if [ -z "$COMFYUI_DIR" ]; then
    echo -e "${RED}ComfyUI not found in common locations${NC}"
    echo -e "Please specify your ComfyUI directory:"
    echo -e "  ${BLUE}$0 /path/to/ComfyUI${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found ComfyUI at: $COMFYUI_DIR${NC}\n"

# Show available models
find_models "$COMFYUI_DIR"

# Generate upload instructions
generate_upload_commands "$COMFYUI_DIR"

# Show how to get file IDs
get_file_ids

# Optional CLI tool
install_gdrive_cli

echo -e "\n${GREEN}=== Quick Copy-Paste for Terminal ===${NC}"
echo -e "To see large models only (>1GB):"
echo -e "${BLUE}find $COMFYUI_DIR/models -type f -name '*.safetensors' -size +1G -exec ls -lh {} \;${NC}"

echo -e "\n${YELLOW}Remember:${NC} After uploading, update the gdrive_id in:"
echo -e "  ${BLUE}vexa-stack/configs/model_manifest.json${NC}"