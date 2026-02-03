#!/bin/bash
echo "version: 2026.02.03"

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TẢI LTX-2 VIDEO GENERATION MODEL ---"

# Check Token (LTX-2 có thể yêu cầu login tùy theo cấu hình HuggingFace)
if [ -z "$HF_TOKEN" ]; then
    echo "ℹ️  Info: Chưa có HF_TOKEN (Nếu link download bị lỗi 403, hãy cung cấp token)."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

# Định nghĩa các ngưỡng kích thước tối thiểu (bytes)
MIN_SIZE_CHECKPOINT=5000000000 # ~5GB cho các bản 19B
MIN_SIZE_TEXT=1000000000       # ~1GB cho Gemma 3
MIN_SIZE_LORA=50000000         # ~50MB

# Hàm tải thông minh với tham số AUTH
function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}; local need_auth=${5:-false}

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    # B1: Kiểm tra file cũ
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (✅ OK: $(($size / 1024 / 1024 / 1024)) GB)"
            return
        else 
            echo " [DELETE] $name lỗi/rỗng ($(($size)) bytes) -> Tải lại."
            rm -f "$filepath"
        fi
    fi
    
    echo " [DOWNLOADING] $name ..."
    
    # B2: Cấu hình wget
    WGET_ARGS=("-q" "--show-progress" "-L" "--no-check-certificate" "-U" "Mozilla/5.0")
    
    if [[ "$need_auth" == "true" ]] && [[ -n "$HF_TOKEN" ]]; then
        WGET_ARGS+=("--header=Authorization: Bearer $HF_TOKEN")
    fi

    # B3: Thực thi
    wget "${WGET_ARGS[@]}" -O "$filepath" "$url"

    # B4: Kiểm tra kết quả
    if [ -f "$filepath" ]; then
        local new_size=$(stat -c%s "$filepath")
        if [ "$new_size" -lt "$min_size" ]; then
            echo " ❌ LỖI: File không đủ dung lượng yêu cầu. ($name)"
            rm -f "$filepath"
        else
            echo " ✅ Thành công: $name ($(($new_size / 1024 / 1024)) MB)"
        fi
    else
        echo " ❌ LỖI: Không tải được file."
    fi
}

echo "--- 📥 BẮT ĐẦU TẢI CÁC THÀNH PHẦN LTX-2 ---"

# 1. Checkpoints (Main Diffusion Models)
echo "🔹 Tải Checkpoints LTX-2..."
smart_download "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev.safetensors" \
    "$COMFY_ROOT/models/checkpoints" "ltx-2-19b-dev.safetensors" $MIN_SIZE_CHECKPOINT true

smart_download "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev-fp8.safetensors" \
    "$COMFY_ROOT/models/checkpoints" "ltx-2-19b-dev-fp8.safetensors" $MIN_SIZE_CHECKPOINT true

# 2. Text Encoder (Gemma 3 12B IT)
echo "🔹 Tải Gemma 3 Text Encoder..."
smart_download "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "gemma_3_12B_it_fp4_mixed.safetensors" $MIN_SIZE_TEXT

# 3. LoRAs (Distilled & Camera Control)
echo "🔹 Tải LTX-2 LoRAs..."
smart_download "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors" \
    "$COMFY_ROOT/models/loras" "ltx-2-19b-distilled-lora-384.safetensors" $MIN_SIZE_LORA true

smart_download "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors" \
    "$COMFY_ROOT/models/loras" "ltx-2-19b-lora-camera-control-dolly-left.safetensors" $MIN_SIZE_LORA true

# 4. Latent Upscale Models
echo "🔹 Tải Spatial Upscaler..."
smart_download "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors" \
    "$COMFY_ROOT/models/latent_upscale_models" "ltx-2-spatial-upscaler-x2-1.0.safetensors" $MIN_SIZE_LORA true

echo "--- ✅ HOÀN TẤT QUÁ TRÌNH CÀI ĐẶT LTX-2 ---"
echo "💡 Lưu ý: Hãy đảm bảo ComfyUI của bạn đã được cập nhật phiên bản mới nhất để hỗ trợ Gemma 3 và LTX-2."
