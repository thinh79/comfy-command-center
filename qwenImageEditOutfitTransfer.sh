#!/bin/bash

# Tên file: qwenImageEditOutfitTransfer.sh
MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT: QWEN OUTFIT TRANSFER SETUP ---"

# Check Token (Cần thiết nếu tải model gated từ HF, script này chủ yếu dùng model public)
if [ -z "$HF_TOKEN" ]; then
    echo "ℹ️  Info: Chưa có HF_TOKEN (Chỉ tải được model Public)."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_LORA=10000000         # 10MB
MIN_SIZE_OTHER=1000000         # 1MB

# Hàm tải thông minh
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
            echo " [DELETE] $name lỗi/rỗng ($(($size)) bytes) -> Tải lại."
            rm -f "$filepath"
        fi
    fi
    
    echo " [DOWNLOADING] $name ..."
    WGET_ARGS=("-q" "--show-progress" "-L" "--no-check-certificate" "-U" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    if [[ "$need_auth" == "true" ]] && [[ -n "$HF_TOKEN" ]]; then
        WGET_ARGS+=("--header=Authorization: Bearer $HF_TOKEN")
    fi
    wget "${WGET_ARGS[@]}" -O "$filepath" "$url"

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

echo "--- 📥 TẢI CÁC THÀNH PHẦN QWEN OUTFIT ---"

# 1. Qwen Text Encoder & VAE (Dựa trên ảnh Missing Models)
# Lưu ý: Tạo thư mục text_encoders riêng biệt theo yêu cầu của node
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_2.5_vl_7b_fp8_scaled.safetensors" $MIN_SIZE_CHECKPOINT

smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "$COMFY_ROOT/models/vae" "qwen_image_vae.safetensors" $MIN_SIZE_OTHER

# 2. LoRAs cho Outfit Transfer (Dựa trên Links & JSON Rename)
# LoRA 1: Outfit Transfer Helper -> Đổi tên thành 'clothtransfer.safetensors' theo Node 172
smart_download "https://civitai.com/api/download/models/2388664?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "clothtransfer.safetensors" $MIN_SIZE_LORA

# LoRA 2: Outfit Extractor -> Đổi tên thành 'extract-outfit_v3.safetensors' theo Node 159
smart_download "https://civitai.com/api/download/models/2196307?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "extract-outfit_v3.safetensors" $MIN_SIZE_LORA

# 3. Các thành phần bổ trợ (ControlNet & Upscale - Workflow này cần OpenPose)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

# 4. Checkpoint gốc (Phòng trường hợp cần dùng SD1.5 để hỗ trợ)
smart_download "https://civitai.com/api/download/models/176425?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    "$COMFY_ROOT/models/checkpoints" "majicmixRealistic_v7.safetensors" $MIN_SIZE_CHECKPOINT

echo "--- ✅ CÀI ĐẶT HOÀN TẤT! HÃY REFRESH COMFYUI ---"
