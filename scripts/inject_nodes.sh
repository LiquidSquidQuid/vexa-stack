#!/bin/bash

# Custom node injection script for ComfyUI
# Installs custom nodes based on manifest file

set -e

COMFYUI_DIR="${1:-/workspace/ComfyUI}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/../configs/node_manifest.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Track if restart is needed
RESTART_NEEDED=false

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq for JSON parsing...${NC}"
    apt-get update && apt-get install -y jq 2>/dev/null || \
    yum install -y jq 2>/dev/null || \
    echo "Warning: Could not install jq"
fi

# Function to install a custom node
install_node() {
    local name="$1"
    local url="$2"
    local description="$3"
    local post_install="$4"
    local required="$5"
    
    echo -e "${BLUE}Installing: $name${NC}"
    echo -e "  $description"
    
    local node_dir="$COMFYUI_DIR/custom_nodes/$name"
    
    # Check if already installed
    if [ -d "$node_dir" ]; then
        echo -e "${GREEN}  ✓ Already installed${NC}"
        # Optional: update the node
        if [ -d "$node_dir/.git" ]; then
            echo -e "${YELLOW}  Updating...${NC}"
            cd "$node_dir"
            git pull --quiet 2>/dev/null || echo "  Warning: Could not update"
            cd - > /dev/null
        fi
    else
        # Clone the repository
        echo -e "${YELLOW}  Cloning repository...${NC}"
        cd "$COMFYUI_DIR/custom_nodes"
        if git clone --depth 1 "$url" "$name" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Cloned successfully${NC}"
        else
            echo -e "${RED}  ✗ Failed to clone${NC}"
            if [ "$required" == "true" ]; then
                echo -e "${RED}  Error: Required node failed to install${NC}"
                return 1
            fi
            return 0
        fi
        cd - > /dev/null
    fi
    
    # Run post-installation script if specified
    if [ -n "$post_install" ] && [ "$post_install" != "null" ]; then
        echo -e "${YELLOW}  Running post-install: $post_install${NC}"
        cd "$node_dir"
        
        # Check if we need to use specific Python
        if [ -n "$PYTHON_BIN" ]; then
            # Replace 'pip' with appropriate pip command
            post_install="${post_install//pip install/$PYTHON_BIN -m pip install}"
            post_install="${post_install//python /$PYTHON_BIN }"
        fi
        
        # Execute post-install command
        if eval "$post_install" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Post-install completed${NC}"
        else
            echo -e "${YELLOW}  Warning: Post-install may have failed${NC}"
        fi
        cd - > /dev/null
    fi
    
    return 0
}

# Process the manifest file
process_manifest() {
    if [ ! -f "$MANIFEST_FILE" ]; then
        echo -e "${RED}Error: Node manifest not found: $MANIFEST_FILE${NC}"
        return 1
    fi
    
    # Get restart-required nodes
    local restart_nodes=$(jq -r '.install_settings.restart_required_after[]' "$MANIFEST_FILE" 2>/dev/null)
    
    # Count required nodes
    local total_required=$(jq '[.custom_nodes[] | select(.required == true)] | length' "$MANIFEST_FILE")
    echo -e "${YELLOW}Found $total_required required custom nodes${NC}\n"
    
    # Process each node
    local count=0
    while IFS= read -r node; do
        local name=$(echo "$node" | jq -r '.name')
        local url=$(echo "$node" | jq -r '.url')
        local description=$(echo "$node" | jq -r '.description')
        local required=$(echo "$node" | jq -r '.required')
        local post_install=$(echo "$node" | jq -r '.post_install')
        
        # Skip non-required nodes in minimal install
        if [ "$2" == "--required-only" ] && [ "$required" != "true" ]; then
            continue
        fi
        
        if [ "$required" == "true" ]; then
            count=$((count + 1))
            echo -e "${YELLOW}[$count/$total_required] Required Node${NC}"
        else
            echo -e "${YELLOW}[Optional Node]${NC}"
        fi
        
        install_node "$name" "$url" "$description" "$post_install" "$required"
        
        # Check if this node requires restart
        if echo "$restart_nodes" | grep -q "$name"; then
            RESTART_NEEDED=true
            echo -e "${YELLOW}  Note: ComfyUI restart will be needed${NC}"
        fi
        
        echo ""
    done < <(jq -c '.custom_nodes[]' "$MANIFEST_FILE")
}

# Install specific node by name
install_specific_node() {
    local node_name="$1"
    local node=$(jq --arg name "$node_name" '.custom_nodes[] | select(.name == $name)' "$MANIFEST_FILE")
    
    if [ -z "$node" ]; then
        echo -e "${RED}Node not found in manifest: $node_name${NC}"
        return 1
    fi
    
    local url=$(echo "$node" | jq -r '.url')
    local description=$(echo "$node" | jq -r '.description')
    local post_install=$(echo "$node" | jq -r '.post_install')
    local required=$(echo "$node" | jq -r '.required')
    
    install_node "$node_name" "$url" "$description" "$post_install" "$required"
}

# Main execution
echo -e "${GREEN}=== Custom Node Injection for ComfyUI ===${NC}"
echo -e "Target directory: $COMFYUI_DIR/custom_nodes/\n"

# Ensure custom_nodes directory exists
mkdir -p "$COMFYUI_DIR/custom_nodes"

# Source environment detection if not already done
if [ -z "$PYTHON_BIN" ]; then
    source "$SCRIPT_DIR/detect_environment.sh" 2>/dev/null || true
fi

# Check if specific node requested
if [ -n "$2" ] && [ "$2" != "--required-only" ]; then
    install_specific_node "$2"
else
    process_manifest "$@"
fi

# Create restart flag if needed
if [ "$RESTART_NEEDED" = true ]; then
    touch /tmp/comfyui_restart_required
    echo -e "${YELLOW}=== Restart Required ===${NC}"
    echo -e "Some nodes require ComfyUI to be restarted to function properly."
fi

# Summary
echo -e "${GREEN}=== Node Installation Complete ===${NC}"
echo -e "Custom nodes installed in: $COMFYUI_DIR/custom_nodes/"
if [ "$RESTART_NEEDED" = true ]; then
    echo -e "${YELLOW}Note: ComfyUI restart is recommended for new nodes to load${NC}"
fi