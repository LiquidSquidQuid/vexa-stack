# Vexa Stack - ComfyUI Deployment for RunPod

A complete, automated deployment solution for running ComfyUI with the Vexa AI model stack on RunPod's community cloud (non-persistent instances).

## 🎯 Purpose

This repository automates the setup of ComfyUI with:
- Pre-configured models (RealVisXL, Pony Realism)
- Essential custom nodes
- Optimized workflows for Vexa dataset generation
- Smart environment detection
- Automatic port detection

## 🚀 Quick Start

### One-Line Deployment

When you start a RunPod instance, simply run in the terminal:

```bash
cd /workspace && \
git clone https://github.com/LiquidSquidQuid/vexa-stack.git && \
bash vexa-stack/setup.sh
```

This will:
1. Detect your ComfyUI installation and port
2. Download required models (~13GB total)
3. Install custom nodes
4. Copy workflows
5. Configure everything automatically

## 📦 What Gets Installed

### Models (via HuggingFace + Google Drive)
The setup downloads models from HuggingFace and syncs additional models from Google Drive:
- **Drive Folder**: [Your Model Storage](https://drive.google.com/drive/folders/1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L)

**Text-to-Image Models:**
- **RealVisXL V5.0 Lightning** (6.46GB) - Primary photorealistic SDXL model
- **SDXL VAE** (335MB) - For better color reproduction
- **Detail Enhancer LoRA** (50MB) - For fine details
- Various embeddings and upscalers

**Image-to-Video Models (Wan 2.2):**
- **Wan 2.2 I2V High-Noise** (14GB) - First pass diffusion model
- **Wan 2.2 I2V Low-Noise** (14GB) - Refine pass diffusion model
- **UMT5 XXL Text Encoder** (5GB) - Text encoding for Wan
- **CLIP Vision H** (2GB) - Image encoding for I2V
- **Wan VAE** (335MB) - Video VAE

> **Note**: I2V models require 16GB+ VRAM for optimal performance

### Custom Nodes
- ComfyUI Manager
- IPAdapter Plus
- Impact Pack (Face Detailer)
- ControlNet nodes
- AnimateDiff (optional)
- Efficiency nodes
- And more...

### Workflows
**Root workflows:**
- `vexa_sfw_dataset_gen` - Generate SFW training data
- `vexa_image_to_video` - Convert images to video
- `Basic Wan 2_1` - Basic Wan 2.1 workflow
- `Wan2.1 V3.2` - Wan 2.1 version 3.2
- `wan21LowVramComfyUI` - Low VRAM optimized Wan 2.1
- `FINAL Image to Video` - Finalized image to video workflow
- `WanI2V-BySam` - Wan Image to Video by Sam
- `Black Mixture` series - Advanced Wan 2.1 and Flux workflows
- `XXX-Ray DMD2 Basic Workflow` - DMD2 basic workflow

**Image to Video/ folder:**
- `Hunyuan-img2vid` - Hunyuan image to video
- `image to video` - Standard I2V workflow
- `wan21LowVramComfyUI 2` - Low VRAM variant

**Text to Image/ folder:**
- `Aphrodite` - Aphrodite text to image
- `BigLoveXL` - BigLoveXL workflow
- `250319_MICKMUMPITZ_BASICFLUX+CN_V01` - Flux with ControlNet
- `Black Mixture's Ultimate Flux V4` - Advanced Flux workflow
- `XXX-Ray DMD2 Basic Workflow` - DMD2 text to image

## 🛠️ Manual Commands

### Check Installation Health
```bash
bash vexa-stack/utils/health_check.sh
```

### Download All Models from Manifest
```bash
bash vexa-stack/scripts/inject_models.sh /workspace/ComfyUI
```

### Sync Models from Google Drive
```bash
# Uses default folder, or set GDRIVE_FOLDER_ID for custom folder
bash vexa-stack/scripts/download_from_gdrive.sh /workspace/ComfyUI
```

### Install Custom Nodes
```bash
bash vexa-stack/scripts/inject_nodes.sh /workspace/ComfyUI
```

### Restart ComfyUI
```bash
bash vexa-stack/scripts/restart_comfyui.sh
```

## 📁 Repository Structure

```
vexa-stack/
├── setup.sh                    # Main setup script
├── scripts/
│   ├── detect_environment.sh   # Detects ComfyUI location & port
│   ├── inject_models.sh       # Downloads models
│   ├── inject_nodes.sh        # Installs custom nodes
│   ├── inject_workflows.sh    # Copies workflows
│   └── restart_comfyui.sh     # Restart helper
├── configs/
│   ├── model_manifest.json    # Model definitions & URLs
│   ├── node_manifest.json     # Custom node list
│   └── runpod_paths.json      # Common RunPod paths
├── workflows/                  # ComfyUI workflow JSONs
├── prompts/                    # Prompt templates
└── utils/                      # Utility scripts
```

## 📤 Google Drive Integration

### Upload Models from Mac
1. Run the upload helper on your Mac:
   ```bash
   bash scripts/upload_to_gdrive_mac.sh
   ```
2. This will show you which models to upload
3. Drag and drop files to: [Google Drive Folder](https://drive.google.com/drive/folders/1HvM1aNyjj7kh1LXZFH7zbqF_o2cdKY_L)

### Download on RunPod
Models are automatically downloaded from Google Drive during setup. To manually download:
```bash
bash vexa-stack/scripts/download_from_gdrive.sh
```

### Get File IDs (for direct downloads)
1. Right-click file in Google Drive → "Get link"
2. Extract ID from URL: `drive.google.com/file/d/FILE_ID_HERE/view`
3. Update `configs/model_manifest.json` with the ID

## 🔧 Configuration

### Updating Model URLs

Edit `configs/model_manifest.json`:

```json
{
  "type": "checkpoint",
  "name": "your_model.safetensors",
  "url": "https://direct-download-url",
  "size": "6.46GB",
  "required": true
}
```

### Adding Custom Nodes

Edit `configs/node_manifest.json`:

```json
{
  "name": "Custom-Node-Name",
  "url": "https://github.com/author/repo.git",
  "description": "What it does",
  "required": true
}
```

## 🔍 Troubleshooting

### ComfyUI Not Found
The script searches common locations:
- `/workspace/ComfyUI`
- `/workspace/comfyui`
- `/workspace/runpod-slim/ComfyUI`
- `/comfyui`
- `/app/ComfyUI`

If your installation is elsewhere, set it manually:
```bash
export COMFYUI_DIR=/path/to/comfyui
bash vexa-stack/setup.sh
```

### Port Detection Failed
If the script can't detect the port, specify it:
```bash
export COMFYUI_PORT=3000
bash vexa-stack/setup.sh
```

### Model Download Failed
- Check your internet connection
- Some CivitAI models require API tokens
- Hugging Face models should work without authentication
- You can manually download and place in `/workspace/ComfyUI/models/`

### Low VRAM Issues
The script automatically detects VRAM and enables `--lowvram` mode if < 8GB.

## 📊 RunPod Tips

### Recommended GPU Specs
- **Minimum**: RTX 3060 12GB
- **Recommended**: RTX 3090 24GB
- **Best**: RTX 4090 24GB or A100

### Community vs Secure Cloud
- **Community Cloud**: Cheaper, no persistence (this repo designed for this)
- **Secure Cloud**: More expensive, supports network volumes

### Accessing ComfyUI
After setup, access ComfyUI at:
- Web Terminal → `http://localhost:8188` (or detected port)
- Direct URL from RunPod interface

## 🤝 Contributing

Feel free to submit issues and PRs to improve the deployment process.

## 📝 License

MIT License - Use freely for your Vexa project!

## ⚠️ Important Notes

1. **First Run**: Initial setup downloads ~13GB of models - be patient
2. **Non-Persistent**: Everything resets when pod stops - that's why we automate!
3. **API Keys**: Some model sources may require authentication
4. **Workflows**: Your workflows are saved in the repo - customize as needed

## 🎨 Vexa Project Context

This deployment is optimized for creating the Vexa AI influencer:
- Consistent identity generation
- High-quality photorealistic outputs
- Batch processing capabilities
- Easy dataset curation workflow

---

**Built for the Vexa Stack Project** 🚀