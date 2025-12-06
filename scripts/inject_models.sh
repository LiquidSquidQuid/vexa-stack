#!/bin/bash

# Model injection script for ComfyUI
# Downloads models based on manifest file

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/../configs/model_manifest.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq not found, installing...${NC}"
    apt-get update && apt-get install -y jq || yum install -y jq || echo "Failed to install jq"
fi

# Function to download a file with progress
download_with_progress() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local size="$4"
    
    echo -e "${BLUE}  Downloading: $name ($size)${NC}"
    
    # Check if file already exists and has size > 0
    if [ -f "$dest" ] && [ -s "$dest" ]; then
        echo -e "${GREEN}  ✓ Already exists: $name${NC}"
        return 0
    fi
    
    # Create temp file for download
    local temp_file="${dest}.tmp"
    
    # Try wget first (better progress display)
    if command -v wget &> /dev/null; then
        wget --show-progress --progress=bar:force:noscroll \
             --timeout=60 --tries=3 \
             "$url" -O "$temp_file" 2>&1 | \
             grep --line-buffered "%" | \
             sed -u -e "s/^/  /"
    # Fallback to curl
    elif command -v curl &> /dev/null; then
        curl -# -L --connect-timeout 60 --retry 3 \
             "$url" -o "$temp_file"
    else
        echo -e "${RED}  Error: Neither wget nor curl found${NC}"
        return 1
    fi
    
    # Check if download succeeded
    if [ $? -eq 0 ] && [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        mv "$temp_file" "$dest"
        echo -e "${GREEN}  ✓ Downloaded: $name${NC}"
        return 0
    else
        rm -f "$temp_file"
        echo -e "${RED}  ✗ Failed to download: $name${NC}"
        return 1
    fi
}

# Parse JSON manifest and download models
process_manifest() {
    if [ ! -f "$MANIFEST_FILE" ]; then
        echo -e "${RED}Error: Manifest file not found: $MANIFEST_FILE${NC}"
        return 1
    fi
    
    # Get total count of required models
    local total_required=$(jq '[.models[] | select(.required == true)] | length' "$MANIFEST_FILE")
    echo -e "${YELLOW}Found $total_required required models to download${NC}\n"
    
    # Process each model
    local count=0
    while IFS= read -r model; do
        count=$((count + 1))
        
        local type=$(echo "$model" | jq -r '.type')
        local name=$(echo "$model" | jq -r '.name')
        local url=$(echo "$model" | jq -r '.url')
        local size=$(echo "$model" | jq -r '.size')
        local required=$(echo "$model" | jq -r '.required')
        local description=$(echo "$model" | jq -r '.description')
        local source=$(echo "$model" | jq -r '.source // "direct"')
        local gdrive_id=$(echo "$model" | jq -r '.gdrive_id // ""')
        
        # Skip non-required models for now
        if [ "$required" != "true" ]; then
            continue
        fi
        
        # Skip placeholder URLs
        if [[ "$url" == placeholder_* ]]; then
            echo -e "${YELLOW}  Skipping $name (placeholder URL)${NC}"
            continue
        fi
        
        # Handle Google Drive models
        if [ "$source" == "gdrive" ] || [[ "$url" == gdrive://* ]]; then
            echo -e "${BLUE}  Google Drive model detected${NC}"
            # Use the Google Drive download script
            bash "$SCRIPT_DIR/download_from_gdrive.sh" "$COMFYUI_DIR" > /dev/null 2>&1 || {
                echo -e "${YELLOW}  Attempting Google Drive download...${NC}"
                if command -v gdown &> /dev/null || pip install gdown -q; then
                    if [ -n "$gdrive_id" ]; then
                        gdown --id "$gdrive_id" -O "$dest_dir/$name" --quiet || echo -e "${YELLOW}  Manual upload needed${NC}"
                    else
                        echo -e "${YELLOW}  Upload $name to Google Drive folder${NC}"
                    fi
                fi
            }
            continue
        fi
        
        echo -e "${YELLOW}[$count/$total_required] Processing: $name${NC}"
        echo -e "  Type: $type | Size: $size"
        echo -e "  $description"
        
        # Determine destination directory based on type
        case "$type" in
            checkpoint)
                dest_dir="$COMFYUI_DIR/models/checkpoints"
                ;;
            lora)
                dest_dir="$COMFYUI_DIR/models/loras"
                ;;
            vae)
                dest_dir="$COMFYUI_DIR/models/vae"
                ;;
            embedding)
                dest_dir="$COMFYUI_DIR/models/embeddings"
                ;;
            upscale)
                dest_dir="$COMFYUI_DIR/models/upscale_models"
                ;;
            controlnet)
                dest_dir="$COMFYUI_DIR/models/controlnet"
                ;;
            *)
                echo -e "${YELLOW}  Warning: Unknown model type: $type${NC}"
                continue
                ;;
        esac
        
        # Create directory if it doesn't exist
        mkdir -p "$dest_dir"
        
        # Download the model
        dest_file="$dest_dir/$name"
        download_with_progress "$url" "$dest_file" "$name" "$size"
        
        echo ""
    done < <(jq -c '.models[]' "$MANIFEST_FILE")
}

# Function to download a specific model by name
download_specific_model() {
    local model_name="$1"
    local model=$(jq --arg name "$model_name" '.models[] | select(.name == $name)' "$MANIFEST_FILE")
    
    if [ -z "$model" ]; then
        echo -e "${RED}Model not found in manifest: $model_name${NC}"
        return 1
    fi
    
    echo "$model" | jq -c '.' | while IFS= read -r m; do
        local type=$(echo "$m" | jq -r '.type')
        local name=$(echo "$m" | jq -r '.name')
        local url=$(echo "$m" | jq -r '.url')
        local size=$(echo "$m" | jq -r '.size')
        
        case "$type" in
            checkpoint) dest_dir="$COMFYUI_DIR/models/checkpoints" ;;
            lora) dest_dir="$COMFYUI_DIR/models/loras" ;;
            vae) dest_dir="$COMFYUI_DIR/models/vae" ;;
            embedding) dest_dir="$COMFYUI_DIR/models/embeddings" ;;
            upscale) dest_dir="$COMFYUI_DIR/models/upscale_models" ;;
            *) dest_dir="$COMFYUI_DIR/models/$type" ;;
        esac
        
        mkdir -p "$dest_dir"
        download_with_progress "$url" "$dest_dir/$name" "$name" "$size"
    done
}

# Main execution
echo -e "${GREEN}=== Model Injection for ComfyUI ===${NC}"
echo -e "Target directory: $COMFYUI_DIR\n"

# Check if specific model requested
if [ -n "$2" ]; then
    download_specific_model "$2"
else
    process_manifest
fi

# Summary
echo -e "${GREEN}=== Model Download Complete ===${NC}"
echo -e "Models are available in:"
echo -e "  Checkpoints: $COMFYUI_DIR/models/checkpoints/"
echo -e "  LoRAs: $COMFYUI_DIR/models/loras/"
echo -e "  VAEs: $COMFYUI_DIR/models/vae/"