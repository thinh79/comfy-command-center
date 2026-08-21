## general

Tải bộ model tổng hợp cho SD 1.5, FLUX.1-dev, Qwen và Z-Image Turbo.

### Yêu cầu trước khi chạy

- Vast.ai/Linux có ComfyUI tại `/workspace/ComfyUI`
- Có `bash`, `wget` và kết nối Internet ổn định
- Dữ liệu tải dự kiến cho lần cài đầy đủ: **72–82 GB**
- Dung lượng trống yêu cầu: **tối thiểu 85 GB**
- Disk instance khuyến nghị: **120 GB trở lên**
- Cung cấp biến `HF_TOKEN` để tải FLUX.1-dev hoặc model gated
- Restart ComfyUI sau khi tải hoàn tất

Script sẽ hiển thị dung lượng còn trống trước khi tải và dừng nếu còn dưới 25 GB để tránh tạo file model bị hỏng.
Lệnh `general` duy nhất bên dưới cũng tải đủ bộ Z-Image Turbo quantized mà workflow cần: `z_image_turbo_int8_convrot.safetensors`, `qwen_3_4b_fp8_mixed.safetensors` và `ae.safetensors` vào đúng thư mục ComfyUI.

### Cấu hình Vast.ai gợi ý

| Chỉ số | Tối thiểu | Khuyến nghị |
| --- | --- | --- |
| GPU VRAM | 24 GB | 32–48 GB |
| GPU | RTX 3090/4090 | RTX 5090, A6000, L40S hoặc A100 |
| CPU | 8 vCPU | 12–16 vCPU |
| System RAM | 32 GB | 64 GB trở lên |
| Disk | SSD, 500 MB/s | NVMe, 1,000 MB/s trở lên |
| Internet download | 500 Mbps | 1 Gbps trở lên |
| Reliability | 95% | 98% trở lên |
| Machine tier | Verified | Secure Cloud cho production |
| Rental type | On-demand | On-demand với Max Duration đủ dài |

`DLPERF` là điểm hiệu năng deep-learning của Vast.ai: khi so sánh các offer cùng loại GPU, ưu tiên điểm cao hơn và cân đối thêm giá/DLPERF. Cấu hình GPU mạnh không bắt buộc để tải model, nhưng cần thiết khi chạy FLUX, Qwen hoặc Z-Image Turbo. Script tự hiển thị GPU/VRAM, số CPU cores, system RAM và cảnh báo nếu thấp hơn mức tối thiểu.

```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/install.sh)"
```

## zControlnet
```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/zFunControlNetUnion.sh)"
```

## ltx2
```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/ltx2.sh)"
```
## qwen image outfit transfer
```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/qwenImageEditOutfitTransfer.sh)"
```
