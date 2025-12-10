#!/bin/bash

# Cleanup script for ComfyUI generated outputs
# Clears images and videos to free up space on network drive

COMFYUI_DIR="${1:-/workspace/ComfyUI}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Symbols
CHECK="✓"
TRASH="🗑"
FOLDER="📁"

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         COMFYUI OUTPUT CLEANUP                                ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Define output directories
OUTPUT_DIR="$COMFYUI_DIR/output"
TEMP_DIR="$COMFYUI_DIR/temp"
INPUT_DIR="$COMFYUI_DIR/input"

# Function to get directory size
get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Function to count files
count_files() {
    local dir="$1"
    local pattern="$2"
    if [ -d "$dir" ]; then
        find "$dir" -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# Show current usage
echo -e "${BOLD}Current disk usage:${NC}"
echo ""

if [ -d "$OUTPUT_DIR" ]; then
    output_size=$(get_dir_size "$OUTPUT_DIR")
    img_count=$(count_files "$OUTPUT_DIR" "*.png")
    jpg_count=$(count_files "$OUTPUT_DIR" "*.jpg")
    mp4_count=$(count_files "$OUTPUT_DIR" "*.mp4")
    webm_count=$(count_files "$OUTPUT_DIR" "*.webm")
    gif_count=$(count_files "$OUTPUT_DIR" "*.gif")

    echo -e "  ${FOLDER} ${BOLD}output/${NC}     ${YELLOW}${output_size}${NC}"
    echo -e "     ${DIM}├── Images (png): ${img_count}${NC}"
    echo -e "     ${DIM}├── Images (jpg): ${jpg_count}${NC}"
    echo -e "     ${DIM}├── Videos (mp4): ${mp4_count}${NC}"
    echo -e "     ${DIM}├── Videos (webm): ${webm_count}${NC}"
    echo -e "     ${DIM}└── GIFs: ${gif_count}${NC}"
else
    echo -e "  ${FOLDER} ${BOLD}output/${NC}     ${DIM}(not found)${NC}"
fi

if [ -d "$TEMP_DIR" ]; then
    temp_size=$(get_dir_size "$TEMP_DIR")
    temp_count=$(find "$TEMP_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${FOLDER} ${BOLD}temp/${NC}       ${YELLOW}${temp_size}${NC} ${DIM}(${temp_count} files)${NC}"
else
    echo -e "  ${FOLDER} ${BOLD}temp/${NC}       ${DIM}(not found)${NC}"
fi

if [ -d "$INPUT_DIR" ]; then
    input_size=$(get_dir_size "$INPUT_DIR")
    input_count=$(find "$INPUT_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${FOLDER} ${BOLD}input/${NC}      ${YELLOW}${input_size}${NC} ${DIM}(${input_count} files)${NC}"
else
    echo -e "  ${FOLDER} ${BOLD}input/${NC}      ${DIM}(not found)${NC}"
fi

echo ""

# Menu
echo -e "${BOLD}What would you like to clean?${NC}"
echo ""
echo "  1) Clear output folder only (generated images/videos)"
echo "  2) Clear temp folder only (temporary files)"
echo "  3) Clear both output and temp"
echo "  4) Clear everything (output, temp, and input)"
echo "  5) Clear only videos (keep images)"
echo "  6) Clear only images (keep videos)"
echo "  0) Cancel"
echo ""

read -p "Select option (0-6): " choice

case $choice in
    1)
        echo ""
        echo -e "${YELLOW}Clearing output folder...${NC}"
        if [ -d "$OUTPUT_DIR" ]; then
            rm -rf "$OUTPUT_DIR"/*
            echo -e "${GREEN}${CHECK} Output folder cleared${NC}"
        fi
        ;;
    2)
        echo ""
        echo -e "${YELLOW}Clearing temp folder...${NC}"
        if [ -d "$TEMP_DIR" ]; then
            rm -rf "$TEMP_DIR"/*
            echo -e "${GREEN}${CHECK} Temp folder cleared${NC}"
        fi
        ;;
    3)
        echo ""
        echo -e "${YELLOW}Clearing output and temp folders...${NC}"
        if [ -d "$OUTPUT_DIR" ]; then
            rm -rf "$OUTPUT_DIR"/*
            echo -e "${GREEN}${CHECK} Output folder cleared${NC}"
        fi
        if [ -d "$TEMP_DIR" ]; then
            rm -rf "$TEMP_DIR"/*
            echo -e "${GREEN}${CHECK} Temp folder cleared${NC}"
        fi
        ;;
    4)
        echo ""
        echo -e "${RED}${BOLD}WARNING: This will delete ALL files including your input images!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" == "yes" ]; then
            echo -e "${YELLOW}Clearing all folders...${NC}"
            [ -d "$OUTPUT_DIR" ] && rm -rf "$OUTPUT_DIR"/* && echo -e "${GREEN}${CHECK} Output cleared${NC}"
            [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"/* && echo -e "${GREEN}${CHECK} Temp cleared${NC}"
            [ -d "$INPUT_DIR" ] && rm -rf "$INPUT_DIR"/* && echo -e "${GREEN}${CHECK} Input cleared${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    5)
        echo ""
        echo -e "${YELLOW}Clearing videos only...${NC}"
        if [ -d "$OUTPUT_DIR" ]; then
            find "$OUTPUT_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.gif" -o -name "*.avi" -o -name "*.mov" \) -delete
            echo -e "${GREEN}${CHECK} Videos cleared${NC}"
        fi
        ;;
    6)
        echo ""
        echo -e "${YELLOW}Clearing images only...${NC}"
        if [ -d "$OUTPUT_DIR" ]; then
            find "$OUTPUT_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) -delete
            echo -e "${GREEN}${CHECK} Images cleared${NC}"
        fi
        ;;
    0)
        echo "Cancelled."
        exit 0
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

# Show new usage
echo ""
echo -e "${BOLD}Disk usage after cleanup:${NC}"
echo ""
[ -d "$OUTPUT_DIR" ] && echo -e "  ${FOLDER} output/: ${GREEN}$(get_dir_size "$OUTPUT_DIR")${NC}"
[ -d "$TEMP_DIR" ] && echo -e "  ${FOLDER} temp/:   ${GREEN}$(get_dir_size "$TEMP_DIR")${NC}"
[ -d "$INPUT_DIR" ] && echo -e "  ${FOLDER} input/:  ${GREEN}$(get_dir_size "$INPUT_DIR")${NC}"
echo ""
echo -e "${GREEN}${CHECK} Cleanup complete!${NC}"
