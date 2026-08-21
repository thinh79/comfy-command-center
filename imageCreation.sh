#!/bin/bash

COMFY_ROOT="/workspace/ComfyUI"
MIN_SIZE_MODEL=100000000
MIN_SIZE_LORA=10000000
SIZE_Z_IMAGE_TURBO_INT8_CONVROT=6201001296
SIZE_QWEN_3_4B_FP8_MIXED=5631994051
SIZE_Z_IMAGE_AE=335304388

echo "--- 🚀 IMAGE CREATION: Z-IMAGE TURBO + QWEN IMAGE EDIT ---"

if ! command -v wget >/dev/null 2>&1; then
    echo "❌ Thiếu wget."
    exit 1
fi

if [ ! -d "$COMFY_ROOT" ]; then
    echo "❌ Không tìm thấy ComfyUI tại $COMFY_ROOT"
    exit 1
fi

function smart_download {
    local url=$1 dest=$2 name=$3 min_size=${4:-1024}
    local filepath="$dest/$name"
    mkdir -p "$dest"

    if [ -f "$filepath" ]; then
        local size
        size=$(stat -c%s "$filepath")
        if [ "$size" -ge "$min_size" ]; then
            echo " [SKIP] $name (✅ $((size / 1024 / 1024)) MB)"
            return 0
        fi
        echo " [DELETE] $name lỗi/rỗng (${size} bytes) -> tải lại."
        rm -f "$filepath"
    fi

    echo " [DOWNLOADING] $name ..."
    if ! wget -q --show-progress -L --no-check-certificate \
        -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
        -O "$filepath" "$url"; then
        echo " ❌ Không tải được $name"
        rm -f "$filepath"
        return 1
    fi

    local new_size
    new_size=$(stat -c%s "$filepath")
    if [ "$new_size" -lt "$min_size" ]; then
        echo " ❌ File không hợp lệ: $name (${new_size} bytes)"
        rm -f "$filepath"
        return 1
    fi
    echo " ✅ Thành công: $name ($((new_size / 1024 / 1024)) MB)"
}

FAILURES=0

# Z-Image Turbo quantized: UNET + text encoder + VAE
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_int8_convrot.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "z_image_turbo_int8_convrot.safetensors" "$SIZE_Z_IMAGE_TURBO_INT8_CONVROT" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b_fp8_mixed.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_3_4b_fp8_mixed.safetensors" "$SIZE_QWEN_3_4B_FP8_MIXED" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
    "$COMFY_ROOT/models/vae" "ae.safetensors" "$SIZE_Z_IMAGE_AE" || FAILURES=$((FAILURES + 1))

# Qwen Image Edit core + Lightning LoRA
smart_download "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" \
    "$COMFY_ROOT/models/loras" "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" "$MIN_SIZE_LORA" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "qwen_image_edit_2509_fp8_e4m3fn.safetensors" "$MIN_SIZE_MODEL" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_2.5_vl_7b_fp8_scaled.safetensors" "$MIN_SIZE_MODEL" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "$COMFY_ROOT/models/vae" "qwen_image_vae.safetensors" "$MIN_SIZE_MODEL" || FAILURES=$((FAILURES + 1))

if [ "$FAILURES" -gt 0 ]; then
    echo "--- ❌ Hoàn tất với $FAILURES lỗi tải model ---"
    exit 1
fi

echo "--- ✅ ĐÃ CÀI ĐỦ IMAGE CREATION. Hãy restart ComfyUI. ---"
