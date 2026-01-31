#!/bin/bash

# --- CẤU HÌNH ---
# Tự động lấy URL của repo hiện tại (nếu file này được clone về)
# Hoặc bạn có thể điền cứng: REPO_URL="https://github.com/thinh79/comfy-command-center.git"
MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TRUNG TÂM CHỈ HUY (Vast.ai) ---"

# A. CẬP NHẬT KIẾN THỨC & WORKFLOW
if [ -d "$MY_DIR" ]; then
    echo " [UPDATE] Đang cập nhật thay đổi mới nhất từ GitHub..."
    cd "$MY_DIR" && git pull
else
    echo " [INFO] Repo chưa được clone. Đang chạy ở chế độ tải file đơn lẻ."
fi

# B. LIÊN KẾT WORKFLOW VÀO COMFYUI
# Tạo shortcut để Load workflow nhanh hơn
if [ ! -d "/workspace/My_Workflows" ] && [ -d "$MY_DIR/workflows" ]; then
    ln -s "$MY_DIR/workflows" "/workspace/My_Workflows"
    echo " [LINK] Đã tạo shortcut '/workspace/My_Workflows' trỏ về Repo."
fi

# C. HÀM TẢI MODEL THÔNG MINH
MIN_SIZE=100000
function smart_download {
    local url=$1; local dest=$2; local name=$3
    mkdir -p "$dest"
    local filepath="$dest/$name"
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -gt "$MIN_SIZE" ]; then echo " [SKIP] $name (Đã có)"; return; else rm "$filepath"; fi
    fi
    echo " [DOWNLOADING] $name ..."
    wget -q --show-progress -O "$filepath" "$url"
}

echo "--- 📥 TẢI MODELS ---"

# --- LIST MODEL CỦA BẠN (Thêm/Sửa ở đây) ---

# 1. ControlNet OpenPose
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors?download=true" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

# 2. Checkpoint MajicMix
smart_download "https://civitai.com/api/download/models/176425?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    "$COMFY_ROOT/models/checkpoints" "majicmixRealistic_v7.safetensors"

# 3. VAE
smart_download "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors?download=true" \
    "$COMFY_ROOT/models/vae" "vae-ft-mse-840000-ema-pruned.safetensors"

# 4. Custom Nodes (Ví dụ cài ComfyUI Manager tự động)
if [ ! -d "$COMFY_ROOT/custom_nodes/ComfyUI-Manager" ]; then
    echo " [GIT] Cloning ComfyUI Manager..."
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$COMFY_ROOT/custom_nodes/ComfyUI-Manager"
fi

echo "--- ✅ DONE! CHIẾN THÔI ---"
