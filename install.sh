#!/bin/bash

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TRUNG TÂM CHỈ HUY (V3 - DEEP FIX) ---"

# Check Token
if [ -z "$HF_TOKEN" ]; then
    echo "⚠️  CẢNH BÁO: Không thấy HF_TOKEN. Model FLUX gốc sẽ KHÔNG tải được."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

# Ngưỡng dung lượng tối thiểu (Bytes)
MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_CLIP=50000000         # 50MB
MIN_SIZE_SMALL=1024            # 1KB (Cho các file nhỏ)

function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    # --- BƯỚC 1: KIỂM TRA FILE CŨ ---
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (✅ OK: $(($size / 1024 / 1024)) MB)"
            return
        else 
            echo " [DELETE] $name bị lỗi/rỗng ($(($size)) bytes) -> Xóa để tải lại."
            rm -f "$filepath"
        fi
    fi
    
    echo " [DOWNLOADING] $name ..."
    
    # --- BƯỚC 2: TẢI FILE (Cấu hình wget mạnh nhất) ---
    # -L: Follow redirects (Quan trọng cho HuggingFace)
    # -t 3: Thử lại 3 lần nếu đứt mạng
    # --content-disposition: Tự xử lý tên file nếu server đổi hướng
    
    local header_args=""
    if [[ "$url" == *"huggingface.co"* ]] && [[ -n "$HF_TOKEN" ]]; then
        header_args="--header=Authorization:Bearer $HF_TOKEN"
    fi

    # Chạy wget (Không dùng -q để hiện lỗi nếu có)
    wget --show-progress -L -t 3 --no-check-certificate \
         $header_args \
         -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
         -O "$filepath" "$url"

    # --- BƯỚC 3: KIỂM TRA KẾT QUẢ NGAY LẬP TỨC ---
    if [ -f "$filepath" ]; then
        local new_size=$(stat -c%s "$filepath")
        if [ "$new_size" -lt "$min_size" ]; then
            echo " ❌ LỖI: Tải xong nhưng file vẫn quá nhẹ ($new_size bytes). URL có vấn đề hoặc sai Token."
            rm -f "$filepath" # Xóa ngay để không gây rác
        else
            echo " ✅ Đã tải xong: $name ($(($new_size / 1024 / 1024)) MB)"
        fi
    else
        echo " ❌ LỖI: Không tạo được file."
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

# 3. Upscalers (Dùng link khác ổn định hơn)
# Link UltraSharp này từ nguồn backup, dễ tải hơn link comfyanonymous cũ
smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

smart_download "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth" \
    "$COMFY_ROOT/models/upscale_models" "RealESRGAN_x4plus.pth"

# 4. ControlNet Essential
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_depth_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_depth_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_tile_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_tile_fp16.safetensors"

# 5. Flux Dev (Cần Token)
# LƯU Ý: Nếu vẫn lỗi 0KB, nghĩa là tài khoản HF của bạn chưa bấm "Accept Terms" trên web HuggingFace
smart_download "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
    "$COMFY_ROOT/models/unet" "flux1-dev.safetensors" $MIN_SIZE_CHECKPOINT

# 6. Clip L (Link chuẩn)
smart_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$COMFY_ROOT/models/clip" "clip_l.safetensors" $MIN_SIZE_CLIP

echo "--- ✅ DONE! ---"
