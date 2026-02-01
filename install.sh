#!/bin/bash

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TRUNG TÂM CHỈ HUY (VAST.AI VERSION) ---"

# Kiểm tra xem máy đã nhận Token chưa
if [ -z "$HF_TOKEN" ]; then
    echo "⚠️ CẢNH BÁO: Không tìm thấy HF_TOKEN trong biến môi trường!"
    echo "   -> Các model FLUX gốc (Black Forest Labs) sẽ LỖI tải xuống."
    echo "   -> Hãy chắc chắn bạn đã set HF_TOKEN trong Edit Image -> Environment Variables."
else
    echo "✅ Đã tìm thấy HF_TOKEN! Sẽ sử dụng để tải các model bảo mật."
fi

# Tăng giới hạn kiểm tra lỗi
MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_CLIP=50000000         # 50MB

function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1000}

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (Đã có: $(($size / 1024 / 1024)) MB)"
            return
        else 
            echo " [DELETE] $name quá nhẹ ($(($size / 1024)) KB) -> Nghi ngờ lỗi -> Tải lại."
            rm "$filepath"
        fi
    fi
    
    echo " [DOWNLOADING] $name ..."
    
    # --- LOGIC MỚI: TỰ ĐỘNG CHÈN TOKEN ---
    # Nếu URL là HuggingFace VÀ có Token -> Thêm Header xác thực
    if [[ "$url" == *"huggingface.co"* ]] && [[ -n "$HF_TOKEN" ]]; then
        wget -q --show-progress --no-check-certificate \
             --header="Authorization: Bearer $HF_TOKEN" \
             -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
             -O "$filepath" "$url"
    else
        # Tải thường (Civitai hoặc không có Token)
        wget -q --show-progress --no-check-certificate \
             -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
             -O "$filepath" "$url"
    fi
}

echo "--- 📥 TẢI MODELS ---"

# 1. ControlNet OpenPose
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

# 2. Checkpoint MajicMix
smart_download "https://civitai.com/api/download/models/176425?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    "$COMFY_ROOT/models/checkpoints" "majicmixRealistic_v7.safetensors"

# 3. VAE
smart_download "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
    "$COMFY_ROOT/models/vae" "vae-ft-mse-840000-ema-pruned.safetensors"

# 4. Custom Nodes
if [ ! -d "$COMFY_ROOT/custom_nodes/ComfyUI-Manager" ]; then
    echo " [GIT] Cloning ComfyUI Manager..."
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$COMFY_ROOT/custom_nodes/ComfyUI-Manager"
fi

# 5. Checkpoint Inpainting
smart_download "https://huggingface.co/Comfy-Org/stable_diffusion_2.1_repackaged/resolve/main/512-inpainting-ema.safetensors" \
    "$COMFY_ROOT/models/checkpoints" "512-inpainting-ema.safetensors"

# -------------------------------------------------------
# CÁC FILE HAY BỊ LỖI (Đã fix User-Agent)
# -------------------------------------------------------

# 6. Upscalers (Dùng link dự phòng ổn định hơn)
smart_download "https://huggingface.co/comfyanonymous/ComfyUI_experiments/resolve/main/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

smart_download "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth" \
    "$COMFY_ROOT/models/upscale_models" "RealESRGAN_x4plus.pth"

# 7. Embeddings
smart_download "https://huggingface.co/datasets/gsdf/EasyNegative/resolve/main/EasyNegative.safetensors" \
    "$COMFY_ROOT/models/embeddings" "EasyNegative.safetensors"

smart_download "https://civitai.com/api/download/models/60938" \
    "$COMFY_ROOT/models/embeddings" "bad-hands-5.pt" 

# 8. ControlNet (Sẽ dùng Token nếu cần, nhưng thường là public)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_canny_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_canny_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_depth_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_depth_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_tile_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_tile_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_lineart_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_lineart_fp16.safetensors"

# 9. LoRAs
smart_download "https://huggingface.co/latent-consistency/lcm-lora-sdv1-5/resolve/main/pytorch_lora_weights.safetensors" \
    "$COMFY_ROOT/models/loras" "lcm-lora-sdv1-5.safetensors"

smart_download "https://civitai.com/api/download/models/135931?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "Add_Detail_LoRA.safetensors"

# 10. CLIP Vision & IP-Adapter
mkdir -p "$COMFY_ROOT/models/clip_vision"
smart_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
    "$COMFY_ROOT/models/clip_vision" "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"

mkdir -p "$COMFY_ROOT/models/ipadapter"
smart_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors" \
    "$COMFY_ROOT/models/ipadapter" "ip-adapter-plus_sd15.safetensors"

# --- FLUX SECTION (QUAN TRỌNG: Cần Token) ---

# 12. UNET: Flux.1-dev (GỐC)
# Vì bạn ĐÃ CÓ TOKEN, script này sẽ dùng Token để tải bản gốc 22GB từ Black Forest Labs.
smart_download "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
    "$COMFY_ROOT/models/unet" "flux1-dev.safetensors" $MIN_SIZE_CHECKPOINT

# 13. CLIP & T5
smart_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$COMFY_ROOT/models/clip" "clip_l.safetensors" $MIN_SIZE_CLIP

smart_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "$COMFY_ROOT/models/clip" "t5xxl_fp8_e4m3fn.safetensors" $MIN_SIZE_CLIP

# 14. VAE Flux
smart_download "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "$COMFY_ROOT/models/vae" "flux2-vae.safetensors" $MIN_SIZE_CLIP

echo "--- ✅ DONE! ---"
