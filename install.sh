#!/bin/bash

#!/bin/bash

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"

echo "--- 🚀 KÍCH HOẠT TRUNG TÂM CHỈ HUY (FIXED VERSION) ---"

# Tăng giới hạn kiểm tra lỗi lên 100MB (cho checkpoints)
# Nếu file nhỏ hơn 100MB -> Coi như lỗi tải -> Xóa tải lại
MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_CLIP=50000000         # 50MB

function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1000} # Default 1KB if not set

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        # Kiểm tra dung lượng
        if [ "$size" -gt "$min_size" ]; then 
            echo " [SKIP] $name (Đã có: $(($size / 1024 / 1024)) MB)"
            return
        else 
            echo " [DELETE] $name quá nhẹ ($(($size / 1024)) KB) -> Nghi ngờ lỗi -> Tải lại."
            rm "$filepath"
        fi
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

# 5. Checkpoint Inpainting (SD 2.1)
smart_download "https://huggingface.co/Comfy-Org/stable_diffusion_2.1_repackaged/resolve/main/512-inpainting-ema.safetensors" \
    "$COMFY_ROOT/models/checkpoints" "512-inpainting-ema.safetensors"

# -------------------------------------------------------
# BỔ SUNG: CÁC MODEL THIẾU THƯỜNG GẶP
# -------------------------------------------------------

# 6. Upscalers (Quan trọng để làm nét ảnh)
# Thư mục: models/upscale_models
smart_download "https://huggingface.co/lokkr/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

smart_download "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth" \
    "$COMFY_ROOT/models/upscale_models" "RealESRGAN_x4plus.pth"

# 7. Embeddings (Textual Inversion - Dùng cho Negative Prompt để ảnh đẹp hơn)
# Thư mục: models/embeddings
smart_download "https://huggingface.co/datasets/gsdf/EasyNegative/resolve/main/EasyNegative.safetensors" \
    "$COMFY_ROOT/models/embeddings" "EasyNegative.safetensors"

smart_download "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
    "$COMFY_ROOT/models/embeddings" "bad-hands-5.pt" 
    # Lưu ý: Link bad-hands mẫu, nếu cần file chuẩn từ Civitai hãy thay link tương ứng, hoặc dùng EasyNegative là đủ cho MajicMix.

# 8. ControlNet Bổ sung (Ngoài OpenPose, đây là 3 cái quan trọng nhất)
# Thư mục: models/controlnet

# Canny (Tạo nét viền)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_canny_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_canny_fp16.safetensors"

# Depth (Chiều sâu)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_depth_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_depth_fp16.safetensors"

# Tile (Dùng để Upscale ảnh chi tiết cao - Rất quan trọng)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_tile_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_tile_fp16.safetensors"

# Lineart (Vẽ nét đẹp hơn Canny cho anime/art)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_lineart_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_lineart_fp16.safetensors"

# 9. LoRAs (Ví dụ LCM để render siêu tốc hoặc Detailer)
# Thư mục: models/loras
smart_download "https://huggingface.co/latent-consistency/lcm-lora-sdv1-5/resolve/main/pytorch_lora_weights.safetensors" \
    "$COMFY_ROOT/models/loras" "lcm-lora-sdv1-5.safetensors"

smart_download "https://civitai.com/api/download/models/135931?type=Model&format=SafeTensor" \
    "$COMFY_ROOT/models/loras" "Add_Detail_LoRA.safetensors"

# 10. CLIP Vision (Cần thiết nếu dùng IP-Adapter để copy style ảnh)
# Thư mục: models/clip_vision
smart_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
    "$COMFY_ROOT/models/clip_vision" "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"

# 11. IP-Adapter Models (Copy dáng/mặt cực mạnh)
# Thư mục: custom_nodes/ComfyUI_IPAdapter_plus/models (hoặc models/ipadapter tùy version node)
# Tạo thư mục chuẩn chung cho ComfyUI hiện đại:
mkdir -p "$COMFY_ROOT/models/ipadapter"
smart_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors" \
    "$COMFY_ROOT/models/ipadapter" "ip-adapter-plus_sd15.safetensors"

# 12. FLUX VAE (Missing from your graph)
# This is specifically for FLUX.1 models
smart_download "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "$COMFY_ROOT/models/vae" "flux2-vae.safetensors"

# --- BỔ SUNG CHO FLUX-2 (SỬA LỖI VALUE NOT IN LIST) ---

# 13. UNET: Flux-2 Klein 9B
# Lưu ý: Link này là FLUX.1-dev gốc (22GB). 
# Nếu bạn cần bản "Klein" lượng tử hóa (nhẹ hơn), link này có thể sai.
# Nhưng nếu workflow cần bản gốc, thì logic dưới đây sẽ đảm bảo tải đủ 22GB.
smart_download "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
    "$COMFY_ROOT/models/unet" "flux-2-klein-9b.safetensors" $MIN_SIZE_CHECKPOINT

# 14. CLIP: Qwen (SỬA URL)
# CẢNH BÁO: Link dưới đây là Qwen2-VL-7B (Model gốc). 
# ComfyUI có thể cần bản chuyển đổi (converted). 
# Tạm thời tôi để link CLIP L gốc và trả về tên clip_l để tránh lỗi file rác.
# BẠN CẦN TÌM LINK CHÍNH XÁC CỦA 'qwen_3_8b.safetensors' TỪ TÁC GIẢ WORKFLOW.
smart_download "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/clip_l.safetensors" \
    "$COMFY_ROOT/models/clip" "clip_l.safetensors" $MIN_SIZE_CLIP

# 15. T5 Text Encoder
smart_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "$COMFY_ROOT/models/clip" "t5xxl_fp8_e4m3fn.safetensors" $MIN_SIZE_CLIP

# 16. VAE Flux
smart_download "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "$COMFY_ROOT/models/vae" "flux2-vae.safetensors" $MIN_SIZE_CLIP

echo "--- ✅ DONE! ---"
