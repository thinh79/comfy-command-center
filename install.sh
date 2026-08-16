#!/bin/bash

MY_DIR="/workspace/ai-command-center"
COMFY_ROOT="/workspace/ComfyUI"
ESTIMATED_DOWNLOAD_GB="60-70"
REQUIRED_FREE_GB=70
MIN_SAFE_FREE_GB=25
RECOMMENDED_DISK_GB=100
MIN_WORKFLOW_VRAM_GB=24
MIN_SYSTEM_RAM_GB=32
RECOMMENDED_SYSTEM_RAM_GB=64
MIN_CPU_CORES=8

echo "--- 🚀 KÍCH HOẠT TRUNG TÂM CHỈ HUY (V5 - HYBRID MODE) ---"
echo ""
echo "--- 📋 REQUIRED METADATA / YÊU CẦU TRƯỚC KHI CÀI ---"
echo " • Nền tảng: Linux/Vast.ai với ComfyUI tại $COMFY_ROOT"
echo " • Công cụ: bash, wget, kết nối Internet ổn định"
echo " • Model: SD 1.5, FLUX.1-dev, Qwen và Z-Image Turbo"
echo " • Dữ liệu tải dự kiến: $ESTIMATED_DOWNLOAD_GB GB cho lần cài đầy đủ"
echo " • Dung lượng trống yêu cầu: ít nhất $REQUIRED_FREE_GB GB"
echo " • Disk instance khuyến nghị: từ $RECOMMENDED_DISK_GB GB"
echo " • HF_TOKEN: cần cho FLUX.1-dev và các model gated"
echo " • Sau khi tải xong: restart ComfyUI để nhận model mới"
echo ""
echo "--- 🖥️  GỢI Ý CHỌN MÁY TRÊN VAST.AI ---"
echo " • GPU/VRAM: tối thiểu 24 GB cho workflow nặng; ưu tiên 32-48 GB để giảm offload"
echo " • GPU gợi ý: RTX 3090/4090 trở lên; lý tưởng RTX 5090, A6000, L40S hoặc A100"
echo " • CPU: tối thiểu $MIN_CPU_CORES vCPU; khuyến nghị 12-16 vCPU"
echo " • System RAM: tối thiểu $MIN_SYSTEM_RAM_GB GB; khuyến nghị $RECOMMENDED_SYSTEM_RAM_GB GB"
echo " • Disk: SSD/NVMe từ 500 MB/s; khuyến nghị NVMe từ 1,000 MB/s"
echo " • Internet download: từ 500 Mbps; khuyến nghị 1 Gbps trở lên"
echo " • Reliability: từ 95%; ưu tiên Verified hoặc Secure Cloud"
echo " • DLPERF: chọn điểm cao hơn khi so sánh các máy cùng loại GPU"
echo " • Rental: ưu tiên On-demand và kiểm tra Max Duration đủ dài"

if ! command -v wget >/dev/null 2>&1; then
    echo "❌ Thiếu wget. Hãy cài wget trước khi chạy general."
    exit 1
fi

if [ ! -d "$COMFY_ROOT" ]; then
    echo "❌ Không tìm thấy ComfyUI tại $COMFY_ROOT"
    exit 1
fi

AVAILABLE_KB=$(df -Pk "$COMFY_ROOT" | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_KB / 1024 / 1024))
echo " • Dung lượng trống hiện tại: ${AVAILABLE_GB} GB"

CPU_CORES=$(nproc 2>/dev/null || echo 0)
SYSTEM_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
CPU_CORES=${CPU_CORES:-0}
SYSTEM_RAM_KB=${SYSTEM_RAM_KB:-0}
SYSTEM_RAM_GB=$((SYSTEM_RAM_KB / 1024 / 1024))
echo " • CPU hiện tại: ${CPU_CORES} cores"
echo " • System RAM hiện tại: ${SYSTEM_RAM_GB} GB"

if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)
    if [ -n "$GPU_INFO" ]; then
        GPU_NAME=${GPU_INFO%,*}
        GPU_VRAM_MIB=${GPU_INFO##*, }
        GPU_VRAM_GB=$((GPU_VRAM_MIB / 1024))
        echo " • GPU hiện tại: ${GPU_NAME} (${GPU_VRAM_GB} GB VRAM)"
        if [ "$GPU_VRAM_GB" -lt "$MIN_WORKFLOW_VRAM_GB" ]; then
            echo "⚠️  VRAM dưới ${MIN_WORKFLOW_VRAM_GB} GB: vẫn tải được model nhưng workflow nặng có thể OOM hoặc offload rất chậm."
        fi
    else
        echo "⚠️  nvidia-smi không trả về thông tin GPU. Không thể kiểm tra VRAM."
    fi
else
    echo "⚠️  Không phát hiện NVIDIA GPU/nvidia-smi. Script vẫn tải được model nhưng không thể kiểm tra VRAM."
fi

if [ "$CPU_CORES" -lt "$MIN_CPU_CORES" ]; then
    echo "⚠️  CPU dưới ${MIN_CPU_CORES} cores: tải/cài vẫn được nhưng xử lý và offload có thể chậm."
fi

if [ "$SYSTEM_RAM_GB" -lt "$MIN_SYSTEM_RAM_GB" ]; then
    echo "⚠️  RAM dưới ${MIN_SYSTEM_RAM_GB} GB: không phù hợp cho offload các model lớn."
fi

if [ "$AVAILABLE_GB" -lt "$MIN_SAFE_FREE_GB" ]; then
    echo "❌ Chỉ còn ${AVAILABLE_GB} GB. Cần tối thiểu ${MIN_SAFE_FREE_GB} GB để tránh model bị tải dở."
    echo "   Lần cài đầy đủ cần ít nhất ${REQUIRED_FREE_GB} GB trống. Hãy tăng disk hoặc dọn dung lượng rồi chạy lại."
    exit 1
elif [ "$AVAILABLE_GB" -lt "$REQUIRED_FREE_GB" ]; then
    echo "⚠️  Ít hơn ${REQUIRED_FREE_GB} GB: chỉ nên tiếp tục nếu phần lớn model đã được cài trước đó."
else
    echo "✅ Dung lượng phù hợp cho lần cài đầy đủ."
fi
echo ""

# Check Token
if [ -z "$HF_TOKEN" ]; then
    echo "ℹ️  Info: Chưa có HF_TOKEN (Chỉ tải được model Public)."
else
    echo "✅ Đã nhận HF_TOKEN (Sẽ dùng cho Flux)."
fi

MIN_SIZE_CHECKPOINT=100000000  # 100MB
MIN_SIZE_CLIP=50000000         # 50MB
SIZE_Z_IMAGE_TURBO_BF16=12309866400
SIZE_QWEN_3_4B=8044982048

# Hàm tải thông minh với tham số AUTH (Xác thực)
function smart_download {
    local url=$1; local dest=$2; local name=$3; local min_size=${4:-1024}; local need_auth=${5:-false}

    mkdir -p "$dest"
    local filepath="$dest/$name"
    
    # B1: Kiểm tra file cũ
    if [ -f "$filepath" ]; then
        local size=$(stat -c%s "$filepath")
        if [ "$size" -ge "$min_size" ]; then
            echo " [SKIP] $name (✅ OK: $(($size / 1024 / 1024)) MB)"
            return
        else 
            echo " [DELETE] $name lỗi/rỗng ($(($size)) bytes) -> Tải lại."
            rm -f "$filepath"
        fi
    fi
    
    echo " [DOWNLOADING] $name ..."
    
    # B2: Cấu hình wget
    # Mặc định: Giả lập trình duyệt, Follow redirect
    WGET_ARGS=("-q" "--show-progress" "-L" "--no-check-certificate" "-U" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    
    # CHỈ thêm Token nếu tham số need_auth = true VÀ có Token
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

echo "--- 📥 TẢI MODELS ---"

# 1. Checkpoint & VAE (Public -> KHÔNG dùng Auth)
smart_download "https://civitai.com/api/download/models/176425?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    "$COMFY_ROOT/models/checkpoints" "majicmixRealistic_v7.safetensors" $MIN_SIZE_CHECKPOINT

smart_download "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
    "$COMFY_ROOT/models/vae" "vae-ft-mse-840000-ema-pruned.safetensors"

smart_download "https://huggingface.co/Comfy-Org/stable_diffusion_2.1_repackaged/resolve/main/512-inpainting-ema.safetensors" \
    "$COMFY_ROOT/models/checkpoints" "512-inpainting-ema.safetensors" $MIN_SIZE_CHECKPOINT

# 2. Upscalers (Public -> KHÔNG dùng Auth -> Fix lỗi 0KB)
smart_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$COMFY_ROOT/models/upscale_models" "4x-UltraSharp.pth"

smart_download "https://huggingface.co/ZLUDA/Reliable-ESRGAN/resolve/main/RealESRGAN_x4plus.pth" \
    "$COMFY_ROOT/models/upscale_models" "RealESRGAN_x4plus.pth"

# 3. ControlNet (Public -> KHÔNG dùng Auth -> Fix lỗi 0KB)
smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_openpose_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_openpose_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_depth_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_depth_fp16.safetensors"

smart_download "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_tile_fp16.safetensors" \
    "$COMFY_ROOT/models/controlnet" "control_v11p_sd15_tile_fp16.safetensors"

# 4. FLUX (Gated -> DÙNG Auth = true)
# Bạn đã tải được Flux rồi nên nó sẽ Skip, nhưng tôi vẫn để code chuẩn ở đây
smart_download "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
    "$COMFY_ROOT/models/unet" "flux1-dev.safetensors" $MIN_SIZE_CHECKPOINT "true"

# 5. CLIPs & Qwen (Public -> KHÔNG dùng Auth -> Fix lỗi 0KB)
smart_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$COMFY_ROOT/models/clip" "clip_l.safetensors" $MIN_SIZE_CLIP

# 6. Qwen 2.5 3B (Public -> KHÔNG dùng Auth)
smart_download "https://huggingface.co/prithivML/Qwen2.5-3B-Instruct-SafeTensor/resolve/main/model.safetensors" \
    "$COMFY_ROOT/models/clip" "qwen_3_8b.safetensors" $MIN_SIZE_CLIP

# 7. Z-Image Turbo (Main Model & Text Encoder)
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
    "$COMFY_ROOT/models/diffusion_models" "z_image_turbo_bf16.safetensors" $SIZE_Z_IMAGE_TURBO_BF16

smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
    "$COMFY_ROOT/models/text_encoders" "qwen_3_4b.safetensors" $SIZE_QWEN_3_4B

# 8. Model Patches (Z-Image-Turbo-Fun-Controlnet-Union)
smart_download "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union-2.1.safetensors" \
    "$COMFY_ROOT/models/model_patches" "Z-Image-Turbo-Fun-Controlnet-Union-2.1.safetensors" $MIN_SIZE_CHECKPOINT

echo "--- ✅ DONE! ---"
