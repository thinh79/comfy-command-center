#!/bin/bash

set -o pipefail

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
WORKFLOW_DIR="$COMFY_ROOT/user/default/workflows"
INPUT_DIR="$COMFY_ROOT/input"
GIB=$((1024 * 1024 * 1024))
DOWNLOAD_HEADROOM_BYTES=$((5 * GIB))

SIZE_Z_IMAGE_TURBO_INT8_CONVROT=6201001296
SIZE_QWEN_3_4B_FP8_MIXED=5631994051
SIZE_Z_IMAGE_AE=335304388
SIZE_QWEN_EDIT_LIGHTNING=849608296
SIZE_QWEN_IMAGE_EDIT_FP8=20430635136
SIZE_QWEN_2_5_VL_7B_FP8=9384670680
SIZE_QWEN_IMAGE_VAE=253806246

echo "--- 🚀 IMAGE CREATION: Z-IMAGE TURBO + QWEN IMAGE EDIT ---"

if ! command -v wget >/dev/null 2>&1; then
    echo "❌ Thiếu wget. Hãy cài wget rồi chạy lại."
    exit 1
fi

if [ ! -d "$COMFY_ROOT" ]; then
    echo "❌ Không tìm thấy ComfyUI tại $COMFY_ROOT"
    echo "   Có thể đặt đường dẫn khác bằng biến COMFY_ROOT."
    exit 1
fi

function valid_file {
    local filepath=$1 min_size=$2
    [ -f "$filepath" ] && [ "$(stat -Lc%s "$filepath" 2>/dev/null || echo 0)" -ge "$min_size" ]
}

function missing_bytes {
    local filepath=$1 expected_size=$2
    if valid_file "$filepath" "$expected_size"; then echo 0; else echo "$expected_size"; fi
}

REQUIRED_BYTES=0
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/diffusion_models/z_image_turbo_int8_convrot.safetensors" "$SIZE_Z_IMAGE_TURBO_INT8_CONVROT")))
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/text_encoders/qwen_3_4b_fp8_mixed.safetensors" "$SIZE_QWEN_3_4B_FP8_MIXED")))
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/vae/ae.safetensors" "$SIZE_Z_IMAGE_AE")))
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/loras/Qwen-Image-Edit-Lightning-4steps-V1.0-bf16.safetensors" "$SIZE_QWEN_EDIT_LIGHTNING")))
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" "$SIZE_QWEN_IMAGE_EDIT_FP8")))
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" "$SIZE_QWEN_2_5_VL_7B_FP8")))
REQUIRED_BYTES=$((REQUIRED_BYTES + $(missing_bytes "$COMFY_ROOT/models/vae/qwen_image_vae.safetensors" "$SIZE_QWEN_IMAGE_VAE")))

AVAILABLE_KB=$(df -Pk "$COMFY_ROOT" | awk 'NR==2 {print $4}')
AVAILABLE_BYTES=$((AVAILABLE_KB * 1024))
SAFE_REQUIRED_BYTES=$((REQUIRED_BYTES + DOWNLOAD_HEADROOM_BYTES))
echo " • Cần tải thêm: $((REQUIRED_BYTES / GIB)) GiB"
echo " • Dung lượng trống: $((AVAILABLE_BYTES / GIB)) GiB"
if [ "$AVAILABLE_BYTES" -lt "$SAFE_REQUIRED_BYTES" ]; then
    echo "❌ Không đủ dung lượng. Cần khoảng $((SAFE_REQUIRED_BYTES / GIB + 1)) GiB, gồm 5 GiB dự phòng."
    exit 1
fi

PYTHON_BIN=""
for candidate in "$COMFY_ROOT/venv/bin/python" "/workspace/venv/bin/python" "$(command -v python3 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then PYTHON_BIN="$candidate"; break; fi
done

if [ "${SKIP_COMFY_UPDATE:-0}" != "1" ]; then
    echo "--- 🔄 CẬP NHẬT COMFYUI VÀ DEPENDENCIES ---"
    if command -v git >/dev/null 2>&1 && git -C "$COMFY_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [ -z "$(git -C "$COMFY_ROOT" status --porcelain)" ]; then
            git -C "$COMFY_ROOT" pull --ff-only || echo "⚠️  Không cập nhật được ComfyUI; tiếp tục với phiên bản hiện tại."
        else
            echo "⚠️  ComfyUI có thay đổi local; bỏ qua git pull để không ghi đè dữ liệu."
        fi
    else
        echo "⚠️  ComfyUI không phải bản Git; bỏ qua git pull."
    fi

    if [ -n "$PYTHON_BIN" ] && [ -f "$COMFY_ROOT/requirements.txt" ]; then
        "$PYTHON_BIN" -m pip install -r "$COMFY_ROOT/requirements.txt" || { echo "❌ Không cài được dependencies ComfyUI."; exit 1; }
    else
        echo "⚠️  Không tìm thấy Python environment/requirements.txt; bỏ qua cập nhật dependencies."
    fi
else
    echo "ℹ️  SKIP_COMFY_UPDATE=1: bỏ qua cập nhật ComfyUI."
fi

if [ -n "$PYTHON_BIN" ] && ! "$PYTHON_BIN" -c "import comfy_kitchen" >/dev/null 2>&1; then
    echo "❌ Thiếu comfy_kitchen, cần cho model INT8 ConvRot."
    echo "   Hãy cập nhật ComfyUI và requirements rồi chạy lại."
    exit 1
fi

function smart_download {
    local url=$1 dest=$2 name=$3 expected_size=${4:-1024}
    local filepath="$dest/$name"
    mkdir -p "$dest"

    if valid_file "$filepath" "$expected_size"; then
        local size
        size=$(stat -Lc%s "$filepath")
        echo " [SKIP] $name (✅ $((size / 1024 / 1024)) MB)"
        return 0
    fi

    if [ -f "$filepath" ]; then echo " [RESUME] $name ..."; else echo " [DOWNLOADING] $name ..."; fi
    if ! wget --continue --tries=5 --timeout=30 --retry-connrefused --show-progress -L --no-check-certificate \
        -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -O "$filepath" "$url"; then
        echo " ❌ Không tải được $name; giữ file tạm để lần sau tiếp tục."
        return 1
    fi

    local new_size
    new_size=$(stat -Lc%s "$filepath" 2>/dev/null || echo 0)
    if [ "$new_size" -lt "$expected_size" ]; then
        echo " ❌ File chưa đủ: $name ($new_size/$expected_size bytes)"
        return 1
    fi
    echo " ✅ Thành công: $name ($((new_size / 1024 / 1024)) MB)"
}

FAILURES=0
echo "--- 📥 Z-IMAGE TURBO QUANTIZED ---"
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_int8_convrot.safetensors" "$COMFY_ROOT/models/diffusion_models" "z_image_turbo_int8_convrot.safetensors" "$SIZE_Z_IMAGE_TURBO_INT8_CONVROT" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b_fp8_mixed.safetensors" "$COMFY_ROOT/models/text_encoders" "qwen_3_4b_fp8_mixed.safetensors" "$SIZE_QWEN_3_4B_FP8_MIXED" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" "$COMFY_ROOT/models/vae" "ae.safetensors" "$SIZE_Z_IMAGE_AE" || FAILURES=$((FAILURES + 1))

echo "--- 📥 QWEN IMAGE EDIT ---"
smart_download "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" "$COMFY_ROOT/models/loras" "Qwen-Image-Edit-Lightning-4steps-V1.0-bf16.safetensors" "$SIZE_QWEN_EDIT_LIGHTNING" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_fp8_e4m3fn.safetensors" "$COMFY_ROOT/models/diffusion_models" "qwen_image_edit_fp8_e4m3fn.safetensors" "$SIZE_QWEN_IMAGE_EDIT_FP8" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" "$COMFY_ROOT/models/text_encoders" "qwen_2.5_vl_7b_fp8_scaled.safetensors" "$SIZE_QWEN_2_5_VL_7B_FP8" || FAILURES=$((FAILURES + 1))
smart_download "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" "$COMFY_ROOT/models/vae" "qwen_image_vae.safetensors" "$SIZE_QWEN_IMAGE_VAE" || FAILURES=$((FAILURES + 1))

if [ "$FAILURES" -gt 0 ]; then
    echo "--- ❌ Còn $FAILURES model tải chưa hoàn tất. Chạy lại cùng command để tiếp tục. ---"
    exit 1
fi

echo "--- 📦 CÀI WORKFLOWS VÀ ẢNH MẪU ---"
mkdir -p "$WORKFLOW_DIR" "$INPUT_DIR"
wget -q --tries=5 --timeout=30 -O "$WORKFLOW_DIR/image_z_image_turbo_quantized.json" "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/templates/image_z_image_turbo.json" || exit 1
sed -e 's/z_image_turbo_bf16\.safetensors/z_image_turbo_int8_convrot.safetensors/g' \
    -e 's/qwen_3_4b\.safetensors/qwen_3_4b_fp8_mixed.safetensors/g' \
    "$WORKFLOW_DIR/image_z_image_turbo_quantized.json" > "$WORKFLOW_DIR/image_z_image_turbo_quantized.json.tmp" && \
    mv "$WORKFLOW_DIR/image_z_image_turbo_quantized.json.tmp" "$WORKFLOW_DIR/image_z_image_turbo_quantized.json"
wget -q --tries=5 --timeout=30 -O "$WORKFLOW_DIR/image_qwen_image_edit.json" "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/templates/image_qwen_image_edit.json" || exit 1
wget -q --tries=5 --timeout=30 -O "$INPUT_DIR/image_qwen_image_edit_input_image.png" "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/input/image_qwen_image_edit_input_image.png" || exit 1

if ! grep -q 'z_image_turbo_int8_convrot\.safetensors' "$WORKFLOW_DIR/image_z_image_turbo_quantized.json"; then
    echo "❌ Không chuyển được workflow Z-Image sang model quantized."
    exit 1
fi

echo "--- ✅ IMAGE CREATION ĐÃ SẴN SÀNG ---"
echo " • Workflow: $WORKFLOW_DIR/image_z_image_turbo_quantized.json"
echo " • Workflow: $WORKFLOW_DIR/image_qwen_image_edit.json"
echo " • Ảnh mẫu: $INPUT_DIR/image_qwen_image_edit_input_image.png"
echo " • Hãy restart ComfyUI rồi refresh trình duyệt."
