#!/bin/bash

# --- CẤU HÌNH ---
MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 STARTING: QWEN IMAGE EDIT OUTFIT TRANSFER SETUP ---"
echo "ver 1547"

# --- HÀM TẢI THÔNG MINH ---
function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}
    mkdir -p "$dest"
    local filepath="$dest/$name"
    
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
    wget -q --show-progress -L --no-check-certificate -U "Mozilla/5.0" -O "$filepath" "$url"
}

# --- PHẦN 1: CÀI CUSTOM NODES (BẮT BUỘC ĐỂ WORKFLOW CHẠY) ---
echo "--- 1. KIỂM TRA & CÀI CUSTOM NODES ---"
cd "$COMFY_ROOT/custom_nodes"

# Node Qwen (Bắt buộc cho workflow này)
if [ ! -d "ComfyUI_Qwen-Image-Edit" ]; then
    echo "⬇️ Cloning ComfyUI_Qwen-Image-Edit..."
    git clone https://github.com/Comfy-Org/ComfyUI_Qwen-Image-Edit.git
else
    echo "✅ ComfyUI_Qwen-Image-Edit đã có."
fi

# Node KJNodes (Dùng cho các node Set/Get trong workflow của bạn)
if [ ! -d "ComfyUI-KJNodes" ]; then
    echo "⬇️ Cloning ComfyUI-KJNodes..."
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
else
    echo "✅ ComfyUI-KJNodes đã có."
fi

# --- PHẦN 2: TẢI MODELS (TỰ ĐỔI TÊN KHỚP JSON) ---
echo "--- 2. TẢI MODELS & ĐỔI TÊN CHUẨN JSON ---"

# [QUAN TRỌNG] 1. Main UNET (Node 37)
# JSON yêu cầu: qwen_image_edit_2509_fp8_e4m3fn.safetensors
# Thư mục: models/diffusion_models
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "qwen_image_edit_2509_fp8_e4m3fn.safetensors" 100000000

# [QUAN TRỌNG] 2. LoRA Lightning Tăng tốc (Node 136)
# JSON yêu cầu: Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors
smart_download "https://huggingface.co/StartHua/Qwen-Image-Edit-Lightning-Step4-V1.0/resolve/main/Qwen-Image-Edit-Lightning-Step4-V1.0.safetensors" \
    "$COMFY_ROOT/models/loras" "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" 10000000

# 3. Text Encoder (Node 38)
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_2.5_vl_7b_fp8_scaled.safetensors" 100000000

# 4. VAE (Node 39)
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "$COMFY_ROOT/models/vae" "qwen_image_vae.safetensors" 1000000

# 5. Outfit LoRA 1 (Node 172) -> clothtransfer.safetensors
smart_download "https://civitai.com/api/download/models/2388664?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "clothtransfer.safetensors" 10000000

# 6. Outfit LoRA 2 (Node 159) -> extract-outfit_v3.safetensors
smart_download "https://civitai.com/api/download/models/2196307?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "extract-outfit_v3.safetensors" 10000000

# --- PHẦN 3: MODELS BỔ TRỢ ---
echo "--- 3. TẢI CÁC MODELS PHỤ TRỢ ---"

# ControlNet OpenPose (Cần thiết cho workflow outfit)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors" 10000000

# Upscaler
smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth" 1000000

echo "--- ✅ XONG! HÃY KHỞI ĐỘNG LẠI COMFYUI ---"
