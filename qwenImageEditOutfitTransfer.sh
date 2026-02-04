#!/bin/bash

# Tên file: qwenImageEditOutfitTransfer_FULL.sh
MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT: QWEN OUTFIT TRANSFER (FULL FIX + MODELS) ---"
echo "ver 260204-1555"

# --- 0. CHECK TOKEN ---
if [ -z "$HF_TOKEN" ]; then
    echo "ℹ️  Info: Chưa có HF_TOKEN (Chỉ tải được model Public)."
else
    echo "✅ Đã nhận HF_TOKEN."
fi

# --- 1. HÀM TẢI THÔNG MINH (SKIP NẾU ĐÃ CÓ) ---
function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}; local need_auth=${5:-false}
    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    # Kiểm tra file cũ
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (✅ Đã có: $(($size / 1024 / 1024)) MB)"
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

# --- 2. CÀI CUSTOM NODES (FIX LỖI THIẾU NODE) ---
echo "--- 🛠️ KIỂM TRA & CÀI CUSTOM NODES ---"
mkdir -p "$COMFY_ROOT/custom_nodes"
cd "$COMFY_ROOT/custom_nodes"

# 2.1. Cài KJNodes (Fix lỗi GetNode/SetNode bị đỏ)
if [ ! -d "ComfyUI-KJNodes" ]; then
    echo "⬇️ Cloning ComfyUI-KJNodes (Để fix lỗi GetNode/SetNode)..."
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
    # Cài thư viện phụ thuộc cho KJNodes
    if [ -f "ComfyUI-KJNodes/requirements.txt" ]; then
        echo "📦 Installing requirements for KJNodes..."
        pip install -r ComfyUI-KJNodes/requirements.txt
    fi
else
    echo "✅ ComfyUI-KJNodes đã có."
fi

# 2.2. Cài Qwen Image Edit (Bắt buộc cho workflow)
if [ ! -d "ComfyUI_Qwen-Image-Edit" ]; then
    echo "⬇️ Cloning ComfyUI_Qwen-Image-Edit..."
    git clone https://github.com/Comfy-Org/ComfyUI_Qwen-Image-Edit.git
else
    echo "✅ ComfyUI_Qwen-Image-Edit đã có."
fi

# --- 3. TẢI MODELS (TỰ ĐỔI TÊN KHỚP JSON) ---
echo "--- 📥 TẢI MODELS ---"

# Dung lượng tối thiểu để check lỗi file rỗng
MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_LORA=10000000         # 10MB
MIN_SIZE_OTHER=1000000         # 1MB

# [QUAN TRỌNG] Main UNET (Node 37) -> qwen_image_edit_2509_fp8_e4m3fn.safetensors
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "qwen_image_edit_2509_fp8_e4m3fn.safetensors" $MIN_SIZE_CHECKPOINT

# [QUAN TRỌNG] LoRA Lightning (Node 136) -> Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors
smart_download "https://huggingface.co/StartHua/Qwen-Image-Edit-Lightning-Step4-V1.0/resolve/main/Qwen-Image-Edit-Lightning-Step4-V1.0.safetensors" \
    "$COMFY_ROOT/models/loras" "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" $MIN_SIZE_LORA

# Text Encoder (Node 38)
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_2.5_vl_7b_fp8_scaled.safetensors" $MIN_SIZE_CHECKPOINT

# VAE (Node 39)
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "$COMFY_ROOT/models/vae" "qwen_image_vae.safetensors" $MIN_SIZE_OTHER

# Outfit LoRA 1 (Node 172) -> clothtransfer.safetensors
smart_download "https://civitai.com/api/download/models/2388664?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "clothtransfer.safetensors" $MIN_SIZE_LORA

# Outfit LoRA 2 (Node 159) -> extract-outfit_v3.safetensors
smart_download "https://civitai.com/api/download/models/2196307?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "extract-outfit_v3.safetensors" $MIN_SIZE_LORA

# ControlNet OpenPose
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors" $MIN_SIZE_CHECKPOINT

# Upscaler
smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth" $MIN_SIZE_OTHER

echo "--- ✅ DONE! Script đã hoàn tất. HÃY KHỞI ĐỘNG LẠI (RESTART) COMFYUI ---"
