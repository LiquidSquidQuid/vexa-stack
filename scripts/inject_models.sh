#!/bin/bash

# Model injection script for ComfyUI
# Downloads models based on manifest file with clear progress indicators

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/../configs/model_manifest.json"

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
ARROW="→"
DOWNLOAD="⬇"
FOLDER="📁"
CLOUD="☁"

# Check if jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq not found, installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - try brew
        if command -v brew &> /dev/null; then
            brew install jq
        else
            echo -e "${RED}Please install jq: brew install jq${NC}"
        fi
    else
        # Linux - try apt-get or yum
        apt-get update -qq && apt-get install -y -qq jq 2>/dev/null || yum install -y jq 2>/dev/null || {
            echo -e "${RED}Failed to install jq. Please install manually.${NC}"
        }
    fi
fi

# Function to format file size
format_size() {
    local size="$1"
    echo "$size"
}

# Function to check if file exists and is valid
check_file_status() {
    local path="$1"
    local expected_size="$2"

    if [ -f "$path" ]; then
        local actual_size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo "0")
        if [ "$actual_size" -gt 1000 ]; then
            echo "exists"
        else
            echo "corrupt"
        fi
    else
        echo "missing"
    fi
}

# Function to download a file with progress bar
download_with_progress() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local size="$4"

    # Create temp file for download
    local temp_file="${dest}.downloading"

    # Try wget first (better progress display)
    if command -v wget &> /dev/null; then
        wget --progress=bar:force:noscroll \
             --timeout=60 --tries=3 \
             -q --show-progress \
             "$url" -O "$temp_file" 2>&1 && {
            mv "$temp_file" "$dest"
            return 0
        }
    # Fallback to curl
    elif command -v curl &> /dev/null; then
        curl -# -L --connect-timeout 60 --retry 3 \
             "$url" -o "$temp_file" && {
            mv "$temp_file" "$dest"
            return 0
        }
    fi

    rm -f "$temp_file"
    return 1
}

# Print section header
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Print model status line
print_model_status() {
    local status="$1"
    local name="$2"
    local size="$3"
    local location="$4"

    case "$status" in
        "exists")
            echo -e "  ${GREEN}${CHECK}${NC} ${name} ${DIM}(${size})${NC} ${GREEN}[EXISTS]${NC}"
            ;;
        "downloading")
            echo -e "  ${CYAN}${DOWNLOAD}${NC} ${name} ${DIM}(${size})${NC} ${CYAN}[DOWNLOADING...]${NC}"
            ;;
        "downloaded")
            echo -e "  ${GREEN}${CHECK}${NC} ${name} ${DIM}(${size})${NC} ${GREEN}[DOWNLOADED]${NC}"
            ;;
        "missing")
            echo -e "  ${YELLOW}○${NC} ${name} ${DIM}(${size})${NC} ${YELLOW}[MISSING]${NC}"
            ;;
        "failed")
            echo -e "  ${RED}${CROSS}${NC} ${name} ${DIM}(${size})${NC} ${RED}[FAILED]${NC}"
            ;;
        "gdrive")
            echo -e "  ${BLUE}${CLOUD}${NC} ${name} ${DIM}(${size})${NC} ${BLUE}[GOOGLE DRIVE]${NC}"
            ;;
        "skipped")
            echo -e "  ${DIM}○ ${name} (${size}) [SKIPPED - placeholder URL]${NC}"
            ;;
    esac
}

# Main function to process models
process_manifest() {
    if [ ! -f "$MANIFEST_FILE" ]; then
        echo -e "${RED}Error: Manifest file not found: $MANIFEST_FILE${NC}"
        return 1
    fi

    # Get install category from environment (default: all)
    local INSTALL_CATEGORY="${INSTALL_CATEGORY:-all}"

    print_header "MODEL INVENTORY SCAN"

    echo -e "  Installation mode: ${CYAN}${INSTALL_CATEGORY}${NC}"
    echo ""

    # Arrays to track status
    local existing=()
    local to_download=()
    local gdrive_models=()
    local skipped=()
    local category_skipped=()

    # First pass: scan all models and categorize
    echo -e "${BOLD}Scanning local model directories...${NC}\n"

    while IFS= read -r model; do
        local type=$(echo "$model" | jq -r '.type')
        local name=$(echo "$model" | jq -r '.name')
        local url=$(echo "$model" | jq -r '.url')
        local size=$(echo "$model" | jq -r '.size')
        local required=$(echo "$model" | jq -r '.required')
        local source=$(echo "$model" | jq -r '.source // "direct"')
        local category=$(echo "$model" | jq -r '.category // "t2i"')

        # Skip non-required for now
        [ "$required" != "true" ] && continue

        # Filter by installation category
        if [ "$INSTALL_CATEGORY" != "all" ]; then
            # Always include "shared" models, skip others that don't match
            if [ "$category" != "$INSTALL_CATEGORY" ] && [ "$category" != "shared" ]; then
                category_skipped+=("$name|$size|$category")
                echo -e "  ${DIM}○ ${name} (${size}) [SKIPPED - ${category} only]${NC}"
                continue
            fi
        fi

        # Determine destination directory
        case "$type" in
            checkpoint) dest_dir="$COMFYUI_DIR/models/checkpoints" ;;
            lora) dest_dir="$COMFYUI_DIR/models/loras" ;;
            vae) dest_dir="$COMFYUI_DIR/models/vae" ;;
            embedding) dest_dir="$COMFYUI_DIR/models/embeddings" ;;
            upscale) dest_dir="$COMFYUI_DIR/models/upscale_models" ;;
            controlnet) dest_dir="$COMFYUI_DIR/models/controlnet" ;;
            diffusion_model) dest_dir="$COMFYUI_DIR/models/diffusion_models" ;;
            text_encoder) dest_dir="$COMFYUI_DIR/models/text_encoders" ;;
            clip_vision) dest_dir="$COMFYUI_DIR/models/clip_vision" ;;
            sams) dest_dir="$COMFYUI_DIR/models/sams" ;;
            ultralytics_bbox) dest_dir="$COMFYUI_DIR/models/ultralytics/bbox" ;;
            ultralytics_segm) dest_dir="$COMFYUI_DIR/models/ultralytics/segm" ;;
            *) dest_dir="$COMFYUI_DIR/models/$type" ;;
        esac

        local dest_file="$dest_dir/$name"
        local status=$(check_file_status "$dest_file" "$size")

        # Categorize
        if [[ "$url" == placeholder_* ]]; then
            skipped+=("$name|$size|$type")
            print_model_status "skipped" "$name" "$size" "$type"
        elif [ "$source" == "gdrive" ] || [[ "$url" == gdrive://* ]]; then
            if [ "$status" == "exists" ]; then
                existing+=("$name|$size|$type")
                print_model_status "exists" "$name" "$size" "$type"
            else
                gdrive_models+=("$name|$size|$type|$dest_file")
                print_model_status "gdrive" "$name" "$size" "$type"
            fi
        elif [ "$status" == "exists" ]; then
            existing+=("$name|$size|$type")
            print_model_status "exists" "$name" "$size" "$type"
        else
            to_download+=("$name|$size|$type|$url|$dest_file")
            print_model_status "missing" "$name" "$size" "$type"
        fi

    done < <(jq -c '.models[]' "$MANIFEST_FILE")

    # Summary
    echo ""
    echo -e "${BOLD}┌─────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│         SCAN SUMMARY                │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│${NC} ${GREEN}${CHECK} Already exists:${NC}    ${#existing[@]} models     ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${CYAN}${DOWNLOAD} To download:${NC}       ${#to_download[@]} models     ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${BLUE}${CLOUD} Google Drive:${NC}       ${#gdrive_models[@]} models     ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${DIM}○ Skipped (category):${NC} ${#category_skipped[@]} models     ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${DIM}○ Skipped (other):${NC}    ${#skipped[@]} models     ${BOLD}│${NC}"
    echo -e "${BOLD}└─────────────────────────────────────┘${NC}"

    # Download from direct URLs
    if [ ${#to_download[@]} -gt 0 ]; then
        print_header "DOWNLOADING FROM DIRECT URLS"

        local download_count=0
        local download_success=0
        local download_failed=0

        for item in "${to_download[@]}"; do
            IFS='|' read -r name size type url dest_file <<< "$item"
            download_count=$((download_count + 1))

            echo -e "\n${BOLD}[${download_count}/${#to_download[@]}]${NC} ${name}"
            echo -e "    ${DIM}Size: ${size} | Type: ${type}${NC}"
            echo -e "    ${DIM}URL: ${url:0:60}...${NC}"
            echo ""

            mkdir -p "$(dirname "$dest_file")"

            if download_with_progress "$url" "$dest_file" "$name" "$size"; then
                echo -e "    ${GREEN}${CHECK} Download complete${NC}"
                download_success=$((download_success + 1))
            else
                echo -e "    ${RED}${CROSS} Download failed${NC}"
                download_failed=$((download_failed + 1))
            fi
        done

        echo ""
        echo -e "${BOLD}Download Results:${NC} ${GREEN}${download_success} succeeded${NC}, ${RED}${download_failed} failed${NC}"
    fi

    # Handle Google Drive models
    if [ ${#gdrive_models[@]} -gt 0 ]; then
        print_header "GOOGLE DRIVE MODELS"

        echo -e "${YELLOW}The following models need to be downloaded from Google Drive:${NC}\n"

        for item in "${gdrive_models[@]}"; do
            IFS='|' read -r name size type dest_file <<< "$item"
            echo -e "  ${BLUE}${CLOUD}${NC} ${name} ${DIM}(${size})${NC}"
        done

        echo ""
        echo -e "${BOLD}To download these models:${NC}"
        echo -e "  1. Go to: ${CYAN}https://drive.google.com/drive/folders/1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L${NC}"
        echo -e "  2. Upload the missing model files"
        echo -e "  3. Run: ${CYAN}bash scripts/download_from_gdrive.sh --all${NC}"
        echo ""

        # Try to download from Google Drive
        echo -e "${YELLOW}Attempting automatic Google Drive download...${NC}"
        if command -v gdown &> /dev/null || pip install gdown -q 2>/dev/null; then
            bash "$SCRIPT_DIR/download_from_gdrive.sh" "$COMFYUI_DIR" --all 2>/dev/null || {
                echo -e "${YELLOW}Auto-download not available. Please upload models manually.${NC}"
            }
        fi
    fi
}

# Main execution
echo ""
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║           COMFYUI MODEL INJECTION SYSTEM                      ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${FOLDER} Target: ${CYAN}$COMFYUI_DIR${NC}"
echo -e "  📋 Manifest: ${CYAN}$MANIFEST_FILE${NC}"

# Check if specific model requested
if [ -n "$2" ]; then
    echo -e "\n${YELLOW}Downloading specific model: $2${NC}"
    # TODO: implement specific model download
else
    process_manifest
fi

# Check if Google Drive auto-sync is enabled
gdrive_enabled=$(jq -r '.google_drive.auto_sync // false' "$MANIFEST_FILE" 2>/dev/null)
if [ "$gdrive_enabled" == "true" ]; then
    print_header "GOOGLE DRIVE AUTO-SYNC"

    echo -e "${BLUE}${CLOUD}${NC} Google Drive auto-sync is enabled"
    echo -e "${DIM}All files in your Drive folder will be downloaded and sorted automatically${NC}"
    echo ""

    # Run the Google Drive sync script (non-blocking on failure)
    if [ -f "$SCRIPT_DIR/download_from_gdrive.sh" ]; then
        bash "$SCRIPT_DIR/download_from_gdrive.sh" "$COMFYUI_DIR" || {
            echo -e "${YELLOW}Google Drive sync failed (rate limited or network issue)${NC}"
            echo -e "${YELLOW}This is not critical - continuing with setup...${NC}"
        }
    else
        echo -e "${YELLOW}Google Drive sync script not found${NC}"
    fi
fi

# Final summary
print_header "FINAL STATUS"

echo -e "${BOLD}Model directories:${NC}"
for dir in checkpoints loras vae embeddings upscale_models controlnet diffusion_models text_encoders clip_vision; do
    full_path="$COMFYUI_DIR/models/$dir"
    if [ -d "$full_path" ]; then
        count=$(find "$full_path" -maxdepth 1 -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth" -o -name "*.pt" \) 2>/dev/null | wc -l)
        echo -e "  ${FOLDER} ${dir}: ${GREEN}${count}${NC} files"
    fi
done

echo ""
echo -e "${GREEN}Model injection complete!${NC}"
