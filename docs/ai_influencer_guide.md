# AI Influencer Video Production: Complete Research & Solution
## December 2025 - State of the Art

---

## Executive Summary

After extensive research into what successful AI influencer creators are actually using in production, here's the definitive answer:

### The Winning Stack

| Component | Solution | Why |
|-----------|----------|-----|
| **Base Model** | Phr00t's MEGA v12 NSFW or FusionX | Pre-merged, fast, comprehensive |
| **Speed** | 4 steps, CFG 1 | Built-in accelerators |
| **Face Fix** | ReActor face swap | Guarantees character consistency |
| **Time** | 3-7 minutes total | vs 36+ minutes before |

### Your Previous Issues - Solved

| Problem | Cause | Solution |
|---------|-------|----------|
| 36-minute generation | Wan 2.2 dual-model + too many steps | Pre-merged checkpoint with accelerators = 4 steps |
| Scene cuts | Dual-model handoff | Single-pass merged model |
| Character mismatch | Expecting I2V to preserve identity | ReActor face swap post-processing |
| Blurry output | Aspect ratio + insufficient steps | Correct dimensions + optimized steps |

---

## Part 1: What Creators Actually Use

### The Big Discovery: Pre-Merged Checkpoints

The community has moved away from manually stacking LoRAs. Instead, they use **pre-merged checkpoints** that include:
- Base model
- Speed accelerators (CausVid, Lightx2v, rCM, Lightning)
- Quality enhancers (MPS Reward, AccVideo)
- NSFW LoRAs (in NSFW variants)
- VAE and CLIP included

### Top 3 Production Solutions

#### 1. Phr00t's MEGA v12 (Most Popular)
**Best for**: Fast, all-purpose generation with NSFW capability

```
Model: mega-v12-nsfw.safetensors (~11GB)
Steps: 4
CFG: 1
Sampler: euler_ancestral
Scheduler: beta
```

**What's baked in**:
- WAN22.XX_Palingenesis base
- Fun VACE (bf16)
- rCM + Lightx2v accelerators
- MysticXXX + other NSFW LoRAs
- CLIP and VAE

**Download**:
```bash
wget "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/mega-v12-nsfw.safetensors" \
  -O ComfyUI/models/checkpoints/mega-v12-nsfw.safetensors
```

#### 2. FusionX (Highest Quality)
**Best for**: Maximum quality with slightly more setup

```
Model: Wan2.1_I2V_14B_FusionX_LoRA.safetensors
Steps: 8-10
CFG: 1
Sampler: euler_ancestral
Scheduler: beta
```

**Components merged**:
- CausVid (motion flow)
- AccVideo (temporal alignment)
- MoviiGen 1.1 (cinematic quality)
- MPS Reward LoRA (detail enhancement)

**Download**:
```bash
# FusionX as LoRA (use with Wan 2.1 base)
wget "https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/Wan2.1_I2V_14B_FusionX_LoRA.safetensors" \
  -O ComfyUI/models/loras/Wan2.1_I2V_14B_FusionX_LoRA.safetensors
```

#### 3. Lightx2v Distilled (Fastest)
**Best for**: Maximum speed, testing, drafts

```
Model: Wan 2.1/2.2 base + Lightx2v LoRA
Steps: 4
CFG: 1
```

**Download**:
```bash
# Wan 2.1 I2V 4-step distill LoRA
wget "https://huggingface.co/lightx2v/Wan2.1-I2V-14B-480P-StepDistill-CfgDistill-Lightx2v/resolve/main/loras/Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors" \
  -O ComfyUI/models/loras/lightx2v_i2v_4step.safetensors
```

---

## Part 2: Character Consistency - The Real Solution

### The Hard Truth

**No I2V model perfectly preserves character identity.** This is a fundamental limitation of current technology. The professional solution:

```
Generate motion first (face may drift) → Fix face with ReActor → Done
```

### ReActor Face Swap Pipeline

ReActor swaps your original character's face onto every frame of the generated video, guaranteeing consistency.

**Required Models**:
```bash
# Face swap model
wget "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx" \
  -O ComfyUI/models/insightface/inswapper_128.onnx

# Face restoration
wget "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GPEN-BFR-512.onnx" \
  -O ComfyUI/models/facerestore_models/GPEN-BFR-512.onnx

# Face detection (alternative)
wget "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt" \
  -O ComfyUI/models/ultralytics/bbox/face_yolov8m.pt
```

**Settings**:
| Parameter | Value |
|-----------|-------|
| swap_model | inswapper_128.onnx |
| face_restore_model | GPEN-BFR-512.onnx |
| face_boost | enabled |
| source_image | Your original character image |

### Alternative: Wan Lynx (Native Identity Preservation)

New option that preserves identity during generation (not post-processing):

```bash
# Lynx models (use with Wan 2.1 T2V base)
# IP layers
wget "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-T2V-14B-Lynx_lite_ip_layers_fp16.safetensors" \
  -O ComfyUI/models/diffusion_models/lynx_ip_layers.safetensors

# Resampler  
wget "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/lynx_lite_resampler_fp32.safetensors" \
  -O ComfyUI/models/diffusion_models/lynx_resampler.safetensors
```

**Lynx Settings**:
- ip_scale: 0.5-1.0 (identity strength)
- ref_scale: 0.3-0.7 (reference influence)

---

## Part 3: NSFW-Specific LoRAs

### Pre-Merged in MEGA NSFW

The MEGA NSFW checkpoint already includes:
- MysticXXX v2
- Various body motion LoRAs
- Action-specific training

### Standalone NSFW LoRAs (Add on top)

If using SFW base + custom LoRAs:

| LoRA | Purpose | Strength | Source |
|------|---------|----------|--------|
| CubeyAI General NSFW | General actions | 0.7-0.9 | CivArchive |
| FusionX | Quality + motion | 1.0-2.0 | Civitai |
| Specific action LoRAs | Various | 0.5-0.8 | Search Civitai |

**Important Notes**:
- Only use "low noise" Wan 2.2 LoRAs with merged checkpoints
- Do NOT use "high noise" LoRAs (causes artifacts)
- Wan 2.1 LoRAs are generally compatible

### Block Configuration (Advanced)

For CubeyAI and similar LoRAs with WanVideoWrapper:
```
Blocks 0-19: True
Blocks 20+: False
```

---

## Part 4: Complete Workflow Architecture

### Production Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                       INPUT                                  │
├─────────────────────────────────────────────────────────────┤
│  Character Image: 480x848 (portrait) or 848x480 (landscape) │
│  Motion Prompt: Simple, direct description                   │
│  Reference Face: Original character for face swap            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              VIDEO GENERATION (~2-4 min)                     │
├─────────────────────────────────────────────────────────────┤
│  Load Checkpoint: mega-v12-nsfw.safetensors                 │
│  ├── MODEL, CLIP, VAE all from single file                  │
│  │                                                           │
│  Sampler Settings:                                           │
│  ├── steps: 4                                                │
│  ├── cfg: 1                                                  │
│  ├── sampler: euler_ancestral                                │
│  └── scheduler: beta                                         │
│                                                              │
│  Video Settings:                                             │
│  ├── frames: 81 (5 sec) or 161 (10 sec)                     │
│  └── resolution: 480x848 or 720x1280                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              FACE CONSISTENCY FIX (~1 min)                   │
├─────────────────────────────────────────────────────────────┤
│  ReActor Face Swap                                           │
│  ├── source: Original character image                        │
│  ├── swap_model: inswapper_128.onnx                         │
│  ├── face_restore: GPEN-BFR-512.onnx                        │
│  └── face_boost: enabled                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              FRAME INTERPOLATION (~1 min)                    │
├─────────────────────────────────────────────────────────────┤
│  RIFE v4.6                                                   │
│  ├── multiplier: 2x (16fps → 32fps)                         │
│  └── model: rife46.pth                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       OUTPUT                                 │
├─────────────────────────────────────────────────────────────┤
│  Video Combine                                               │
│  ├── format: h264-mp4                                        │
│  ├── crf: 17-19                                              │
│  └── fps: 24-32                                              │
└─────────────────────────────────────────────────────────────┘

Total time: 4-6 minutes (vs 36+ minutes before)
```

---

## Part 5: Prompting Strategy

### What Works (From Professional Creators)

Quote from Lyna Parker (AI influencer creator):
> "I don't usually write anything specific for lighting or camera control... For sex scenes, I actually prefer not to have too much camera motion anyway."

### Prompt Structure

```
[Subject description]. [Action/motion description]. [Optional: camera/lighting].
```

### Example SFW Prompts

```
A woman with long dark hair wearing a white blouse. She turns her head slowly 
and smiles naturally. Soft natural lighting, shallow depth of field.
```

```
A young woman in athletic wear stretches in a sunlit yoga studio. 
Slow controlled movements. Camera static.
```

### Example NSFW Prompts

The MEGA NSFW checkpoint understands anatomical and action terminology directly. Be descriptive:

```
[Describe appearance]. [Describe specific action with body parts]. 
[Describe motion direction/rhythm]. [Setting/lighting optional].
```

### Negative Prompts

```
cartoon, anime, 3d render, cgi, illustration, painting, drawing, 
blurry, low quality, distorted, morphing, multiple people, 
scene change, jump cut, text, watermark, static, frozen
```

---

## Part 6: All Downloads in One Place

### Option A: MEGA NSFW (Recommended - Simplest)

```bash
# The checkpoint (includes everything)
wget "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/mega-v12-nsfw.safetensors" \
  -P ComfyUI/models/checkpoints/

# ReActor models
wget "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx" \
  -P ComfyUI/models/insightface/

wget "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GPEN-BFR-512.onnx" \
  -P ComfyUI/models/facerestore_models/
```

### Option B: Wan 2.1 + FusionX LoRA (Higher Quality)

```bash
# Base model
wget "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors" \
  -P ComfyUI/models/diffusion_models/

# Text encoder
wget "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  -P ComfyUI/models/text_encoders/

# VAE
wget "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
  -P ComfyUI/models/vae/

# CLIP Vision
wget "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
  -P ComfyUI/models/clip_vision/

# FusionX LoRA
wget "https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/Wan2.1_I2V_14B_FusionX_LoRA.safetensors" \
  -P ComfyUI/models/loras/

# ReActor models (same as above)
```

### Option C: Speed-Optimized (Lightx2v)

```bash
# Base model (same as Option B)
# Plus Lightx2v 4-step LoRA
wget "https://huggingface.co/lightx2v/Wan2.1-I2V-14B-480P-StepDistill-CfgDistill-Lightx2v/resolve/main/loras/Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors" \
  -P ComfyUI/models/loras/
```

---

## Part 7: Custom Nodes Required

Install via ComfyUI Manager:

```
Required:
- ComfyUI-VideoHelperSuite (video output)
- ComfyUI-Frame-Interpolation (RIFE)
- ComfyUI-ReActor (face swap)

Optional:
- ComfyUI-KJNodes (extra utilities)
- ComfyUI-WanVideoWrapper (Kijai's wrapper, for Lynx)
- rgthree-comfy (Power LoRA Loader)
```

---

## Part 8: Quick Reference Card

### MEGA NSFW Setup (Copy This)

```yaml
Model: mega-v12-nsfw.safetensors
Node: Load Checkpoint (standard)
  
Sampler:
  steps: 4
  cfg: 1
  sampler: euler_ancestral
  scheduler: beta
  denoise: 1.0

Video:
  resolution: 480x848 (portrait) or 848x480 (landscape)
  frames: 81 (5 sec) or 161 (10 sec)
  
Face Fix:
  tool: ReActor
  swap_model: inswapper_128.onnx
  restore: GPEN-BFR-512.onnx
  
Output:
  interpolation: RIFE 2x
  format: h264-mp4
  crf: 17-19
  fps: 24-32
```

### FusionX Setup

```yaml
Model: wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors
LoRA: Wan2.1_I2V_14B_FusionX_LoRA.safetensors @ strength 1.0-2.0
  
Sampler:
  steps: 8-10 (or 3-4 at strength 2.0 for speed)
  cfg: 1
  sampler: euler_ancestral
  scheduler: beta
  shift: 3-4
```

---

## Part 9: Troubleshooting

### "Video looks like slideshow"
- Increase frames (81 minimum)
- Add RIFE interpolation
- Check prompt for "static" words

### "Face changes mid-video"
- Normal behavior - use ReActor face swap
- Or try Wan Lynx for native preservation

### "Motion too exaggerated"
- Reduce prompt intensity
- Use simpler action descriptions
- Try FusionX instead of MEGA NSFW

### "Not following prompt"
- Simplify prompt
- Be more direct about action
- MEGA checkpoints have LoRA interference - try SFW version + custom LoRAs

### "OOM errors"
- Use fp8 model variants
- Reduce resolution to 480p
- Reduce frame count
- Enable model offloading

---

## Part 10: Your Character LoRA Training

For ultimate consistency, train your own character LoRA:

### Dataset Preparation
- 150-300 full-body images
- Multiple poses, angles, expressions
- Consistent lighting
- Various clothing states
- No text/watermarks

### Training Parameters
```yaml
network_rank: 32-64
learning_rate: 1e-4 to 5e-5
epochs: 10-15
batch_size: 1-2
optimizer: AdamW8bit
```

### Integration
Your trained LoRA works ON TOP of the base checkpoints:
```
Wan 2.1 base → Your Character LoRA → FusionX LoRA → Generation
```

---

## Summary: Your New Workflow

1. **Download** mega-v12-nsfw.safetensors + ReActor models
2. **Load** with standard "Load Checkpoint" node
3. **Configure**: 4 steps, CFG 1, euler_ancestral/beta
4. **Generate** at 480x848 or 720x1280
5. **Face swap** with ReActor using original image
6. **Interpolate** with RIFE 2x
7. **Export** as h264 mp4

**Total time**: ~5 minutes instead of 36+ minutes

---

*Research compiled from: Phr00t/WAN2.2-14B-Rapid-AllInOne, vrgamedevgirl/FusionX, lightx2v distillation models, VirtuaVixen interviews, MimicPC workflows, RunComfy guides, Apatero tutorials, Civitai community - December 2025*
