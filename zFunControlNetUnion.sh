#!/bin/bash
echo "version: 1043"

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TẢI Z-IMAGE-TURBO CONTROLNET UNION ---"

# Check Token (Z-Image Turbo thường là Public, nhưng giữ lại logic này cho các models khác nếu cần)
if [ -z "$HF_TOKEN" ]; then
    echo "ℹ️  Info: Chưa có HF_TOKEN (Chỉ tải được model Public)."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_CLIP=50000000         # 50MB

# Hàm tải thông minh với tham số AUTH
function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}; local need_auth=${5:-false}

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    # B1: Kiểm tra file cũ
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
    
    # B2: Cấu hình wget
    WGET_ARGS=("-q" "--show-progress" "-L" "--no-check-certificate" "-U" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    
    if [[ "$need_auth" == "true" ]] && [[ -n "$HF_TOKEN" ]]; then
        WGET_ARGS+=("--header=Authorization: Bearer $HF_TOKEN")
    fi

    # B3: Thực thi
    wget "${WGET_ARGS[@]}" -O "$filepath" "$url"

    # B4: Kiểm tra kết quả
    if [ -f "$filepath" ]; then
        local new_size=$(stat -c%s "$filepath")
        if [ "$new_size" -lt "$min_size" ]; then
            echo " ❌ LỖI: File 0KB. ($name)"
            rm -f "$filepath"
        else
            echo " ✅ Thành công: $name ($(($new_size / 1024 / 1024)) MB)"
        fi
    else
        echo " ❌ LỖI: Không tải được file."
    fi
}

echo "--- 📥 BẮT ĐẦU TẢI CÁC THÀNH PHẦN Z-IMAGE-TURBO ---"
# 1.1. Bản BF16 (Mới thêm theo yêu cầu của bạn) - Khoảng 11.46 GB
echo "🔹 Tải Main Model (BF16)..."
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "z_image_turbo_bf16.safetensors" $MIN_SIZE_CHECKPOINT

# 1.2. Bản FP8Z Image Turbo Main Model (FP8)
# Nơi lưu: ComfyUI/models/diffusion_models/
echo "🔹 Tải Main Model (FP8)..."
smart_download "https://huggingface.co/T5B/Z-Image-Turbo-FP8/resolve/main/z-image-turbo-fp8-e4m3fn.safetensors?download=true" \
    "$COMFY_ROOT/models/diffusion_models" "z_image_turbo_fp8.safetensors" $MIN_SIZE_CHECKPOINT

# 2. Z Image Turbo Fun ControlNet Union Patch
# Nơi lưu: ComfyUI/models/model_patches/
echo "🔹 Tải ControlNet Union Patch..."
smart_download "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
    "$COMFY_ROOT/models/model_patches" "Z-Image-Turbo-Fun-Controlnet-Union.safetensors" $MIN_SIZE_CHECKPOINT

# 3. Qwen Text Encoder (3.4B)
# Nơi lưu: ComfyUI/models/text_encoders/
echo "🔹 Tải Qwen Text Encoder..."
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_3_4b.safetensors" $MIN_SIZE_CLIP

# 4. Flux VAE for Z Image Turbo
# Nơi lưu: ComfyUI/models/vae/
echo "🔹 Tải VAE..."
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
    "$COMFY_ROOT/models/vae" "ae.safetensors" $MIN_SIZE_CLIP

echo "--- ✅ HOÀN TẤT QUÁ TRÌNH CÀI ĐẶT Z-IMAGE-TURBO ---"
