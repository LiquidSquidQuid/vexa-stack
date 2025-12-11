#!/bin/bash

# Environment detection for ComfyUI on RunPod
# Finds ComfyUI installation directory and running port

# Function to detect ComfyUI installation directory
detect_comfyui_installation() {
    # Common ComfyUI installation paths on RunPod
    POSSIBLE_DIRS=(
        "/workspace/ComfyUI"
        "/workspace/comfyui"
        "/workspace/runpod-slim/ComfyUI"
        "/workspace/stable-diffusion-webui/extensions/ComfyUI"
        "/comfyui"
        "/app/ComfyUI"
        "$HOME/ComfyUI"
        "/runpod-volume/ComfyUI"
    )
    
    for dir in "${POSSIBLE_DIRS[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/main.py" ]; then
            export COMFYUI_DIR="$dir"
            return 0
        fi
    done
    
    # Try to find it using locate or find
    if command -v locate &> /dev/null; then
        FOUND_DIR=$(locate "*/ComfyUI/main.py" 2>/dev/null | head -1 | xargs dirname)
        if [ -n "$FOUND_DIR" ]; then
            export COMFYUI_DIR="$FOUND_DIR"
            return 0
        fi
    fi
    
    # Last resort: search common directories
    FOUND_DIR=$(find /workspace /app /home -name "main.py" -path "*/ComfyUI/*" 2>/dev/null | head -1 | xargs dirname)
    if [ -n "$FOUND_DIR" ]; then
        export COMFYUI_DIR="$FOUND_DIR"
        return 0
    fi
    
    return 1
}

# Function to detect ComfyUI port
detect_comfyui_port() {
    # First, check if ComfyUI is running and get port from process
    COMFY_PROCESS=$(ps aux | grep -E "python.*main\.py" | grep -v grep | head -1)
    if [ -n "$COMFY_PROCESS" ]; then
        # Try to extract port from command line arguments
        PORT=$(echo "$COMFY_PROCESS" | grep -oE "\-\-port[= ]+[0-9]+" | grep -oE "[0-9]+" | head -1)
        if [ -n "$PORT" ]; then
            export COMFYUI_PORT="$PORT"
            return 0
        fi
    fi
    
    # Check common ports by testing the API
    COMMON_PORTS=(8188 3000 8080 7860 5000 8000 3001)
    for port in "${COMMON_PORTS[@]}"; do
        if timeout 1 curl -s "http://localhost:$port/system_stats" > /dev/null 2>&1; then
            export COMFYUI_PORT="$port"
            return 0
        fi
        # Also check for ComfyUI specific endpoints
        if timeout 1 curl -s "http://localhost:$port/object_info" > /dev/null 2>&1; then
            export COMFYUI_PORT="$port"
            return 0
        fi
    done
    
    # Check netstat for python processes listening on ports
    if command -v netstat &> /dev/null; then
        LISTENING_PORT=$(netstat -tlnp 2>/dev/null | grep python | grep -oE ":[0-9]+" | grep -oE "[0-9]+" | head -1)
        if [ -n "$LISTENING_PORT" ]; then
            export COMFYUI_PORT="$LISTENING_PORT"
            return 0
        fi
    fi
    
    # Default to 8188 if nothing found
    export COMFYUI_PORT="8188"
    echo "Warning: Could not detect ComfyUI port, defaulting to 8188"
    return 1
}

# Function to detect GPU information
detect_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
        export GPU_INFO="$GPU_NAME ($GPU_MEMORY)"
    else
        export GPU_INFO="No NVIDIA GPU detected"
    fi
}

# Function to detect Python environment
detect_python_env() {
    # Check if we're in a conda environment
    if [ -n "$CONDA_DEFAULT_ENV" ]; then
        export PYTHON_ENV="conda:$CONDA_DEFAULT_ENV"
        export PYTHON_BIN="python"
        return 0
    fi
    
    # Check if we're in a venv
    if [ -n "$VIRTUAL_ENV" ]; then
        export PYTHON_ENV="venv:$VIRTUAL_ENV"
        export PYTHON_BIN="python"
        return 0
    fi
    
    # Check for ComfyUI specific venv
    if [ -d "$COMFYUI_DIR/venv" ]; then
        export PYTHON_ENV="comfyui_venv"
        export PYTHON_BIN="$COMFYUI_DIR/venv/bin/python"
        return 0
    fi
    
    # Default to system python
    export PYTHON_ENV="system"
    export PYTHON_BIN="python3"
}

# Function to check if ComfyUI Manager is installed
check_comfyui_manager() {
    if [ -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
        export HAS_MANAGER="true"
    else
        export HAS_MANAGER="false"
    fi
}

# Export all detected values when sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced
    detect_comfyui_installation
    detect_comfyui_port
    detect_gpu
    detect_python_env
    check_comfyui_manager
else
    # Script is being executed directly
    echo "=== ComfyUI Environment Detection ==="
    detect_comfyui_installation
    echo "ComfyUI Directory: ${COMFYUI_DIR:-Not found}"
    
    detect_comfyui_port
    echo "ComfyUI Port: ${COMFYUI_PORT:-Not detected}"
    
    detect_gpu
    echo "GPU Info: $GPU_INFO"
    
    detect_python_env
    echo "Python Environment: $PYTHON_ENV"
    echo "Python Binary: $PYTHON_BIN"
    
    check_comfyui_manager
    echo "ComfyUI Manager Installed: $HAS_MANAGER"
fi