#!/bin/bash

# Tên file: qwenImageEditOutfitTransfer_FULL.sh
MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT: QWEN OUTFIT TRANSFER (FULL MATCH JSON) ---"

if [ -z "$HF_TOKEN" ]; then
    echo "ℹ️  Info: Chưa có HF_TOKEN (Chỉ tải được model Public)."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_LORA=10000000         # 10MB
MIN_SIZE_OTHER=1000000         # 1MB

function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}; local need_auth=${5:-false}
    mkdir -p "$dest"
    local filepath="$dest/$name"
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (✅ OK: $(($size / 1024 / 1024)) MB)"
            return
        else 
            echo " [DELETE] $name lỗi/rỗng -> Tải lại."
            rm -f "$filepath"
        fi
    fi
    echo " [DOWNLOADING] $name ..."
    WGET_ARGS=("-q" "--show-progress" "-L" "--no-check-certificate" "-U" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    if [[ "$need_auth" == "true" ]] && [[ -n "$HF_TOKEN" ]]; then
        WGET_ARGS+=("--header=Authorization: Bearer $HF_TOKEN")
    fi
    wget "${WGET_ARGS[@]}" -O "$filepath" "$url"
}

echo "--- 📥 1. MODEL CHÍNH (UNET) ---"
# Node 37 yêu cầu file này. Script sẽ tải bản gốc và đổi tên để khớp JSON.
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "qwen_image_edit_2509_fp8_e4m3fn.safetensors" $MIN_SIZE_CHECKPOINT

echo "--- 📥 2. LIGHTNING LORA (Tăng tốc) ---"
# Node 136 yêu cầu file này.
smart_download "https://huggingface.co/StartHua/Qwen-Image-Edit-Lightning-Step4-V1.0/resolve/main/Qwen-Image-Edit-Lightning-Step4-V1.0.safetensors" \
    "$COMFY_ROOT/models/loras" "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" $MIN_SIZE_LORA

echo "--- 📥 3. TEXT ENCODER & VAE ---"
# Node 38 & 39
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_2.5_vl_7b_fp8_scaled.safetensors" $MIN_SIZE_CHECKPOINT

smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "$COMFY_ROOT/models/vae" "qwen_image_vae.safetensors" $MIN_SIZE_OTHER

echo "--- 📥 4. OUTFIT LORAS (Đổi tên khớp JSON) ---"
# Node 172
smart_download "https://civitai.com/api/download/models/2388664?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "clothtransfer.safetensors" $MIN_SIZE_LORA

# Node 159
smart_download "https://civitai.com/api/download/models/2196307?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "extract-outfit_v3.safetensors" $MIN_SIZE_LORA

echo "--- 📥 5. THÀNH PHẦN BỔ TRỢ ---"
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

echo "--- ✅ DONE! SCRIPT ĐÃ CẬP NHẬT ĐẦY ĐỦ CHO WORKFLOW CỦA BẠN ---"
