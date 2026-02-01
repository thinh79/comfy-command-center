#!/bin/bash

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TRUNG TÂM CHỈ HUY (V4 - SYNTAX FIX) ---"

# 1. Kiểm tra Token
if [ -z "$HF_TOKEN" ]; then
    echo "⚠️  CẢNH BÁO: Không thấy HF_TOKEN."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_CLIP=50000000         # 50MB

function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    # Kiểm tra file cũ
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (✅ OK: $(($size / 1024 / 1024)) MB)"
            return
        else 
            echo " [DELETE] $name lỗi/rỗng ($(($size)) bytes) -> Tải lại."
            rm -f "$filepath"
        fi
    fi
    
    echo " [DOWNLOADING] $name ..."
    
    # --- SỬA LỖI QUAN TRỌNG: CÁCH TRUYỀN TOKEN ---
    # Thay vì nối chuỗi biến, ta dùng mảng (array) để wget hiểu đúng tham số
    
    WGET_ARGS=("-q" "--show-progress" "-L" "--no-check-certificate" "-U" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    
    # Chỉ thêm header nếu là link HuggingFace và có Token
    if [[ "$url" == *"huggingface.co"* ]] && [[ -n "$HF_TOKEN" ]]; then
        WGET_ARGS+=("--header=Authorization: Bearer $HF_TOKEN")
    fi

    # Thực thi lệnh wget với mảng tham số
    wget "${WGET_ARGS[@]}" -O "$filepath" "$url"

    # Kiểm tra kết quả
    if [ -f "$filepath" ]; then
        local new_size=$(stat -c%s "$filepath")
        if [ "$new_size" -lt "$min_size" ]; then
            echo " ❌ LỖI: File quá nhẹ ($new_size bytes). Sai Token hoặc chưa Accept Terms."
            rm -f "$filepath"
        else
            echo " ✅ Thành công: $name ($(($new_size / 1024 / 1024)) MB)"
        fi
    else
        echo " ❌ LỖI: Không tải được file."
    fi
}

echo "--- 📥 TẢI MODELS ---"

# 1. Checkpoint MajicMix
smart_download "https://civitai.com/api/download/models/176425?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    "$COMFY_ROOT/models/checkpoints" "majicmixRealistic_v7.safetensors" $MIN_SIZE_CHECKPOINT

# 2. VAE & Inpainting
smart_download "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
    "$COMFY_ROOT/models/vae" "vae-ft-mse-840000-ema-pruned.safetensors"

smart_download "https://huggingface.co/Comfy-Org/stable_diffusion_2.1_repackaged/resolve/main/512-inpainting-ema.safetensors" \
    "$COMFY_ROOT/models/checkpoints" "512-inpainting-ema.safetensors" $MIN_SIZE_CHECKPOINT

# 3. Upscalers (Đã fix link chết RealESRGAN)
smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

# Link mới từ ZLUDA (ổn định hơn ai-forever)
smart_download "https://huggingface.co/ZLUDA/Reliable-ESRGAN/resolve/main/RealESRGAN_x4plus.pth" \
    "$COMFY_ROOT/models/upscale_models" "RealESRGAN_x4plus.pth"

# 4. ControlNet (Link ComfyAnonymous chuẩn, sẽ chạy được khi fix lỗi Token)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_depth_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_depth_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_tile_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_tile_fp16.safetensors"

# 5. Flux Dev
echo "ℹ️ Đang tải Flux.1-Dev... (Nếu lỗi, hãy nhớ Accept Terms trên web HuggingFace)"
smart_download "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
    "$COMFY_ROOT/models/unet" "flux1-dev.safetensors" $MIN_SIZE_CHECKPOINT

# 6. Clip L
smart_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$COMFY_ROOT/models/clip" "clip_l.safetensors" $MIN_SIZE_CLIP

echo "--- ✅ DONE! ---"
