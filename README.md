## Image Creation — Z-Image Turbo + Qwen Image Edit

Một lần chạy sẽ:

- cập nhật ComfyUI và dependencies nếu workspace Git không có thay đổi local;
- tải đủ Z-Image Turbo quantized và bộ lõi Qwen Image Edit/Lightning với resume/retry;
- kiểm tra dung lượng và kích thước model;
- cài sẵn workflow Z-Image quantized, workflow Qwen Image Edit và ảnh mẫu;
- không tải LoRA thay trang phục.

Cần khoảng **41 GiB model** và khuyến nghị tối thiểu **46 GiB dung lượng trống** nếu chưa có model nào. Đặt `SKIP_COMFY_UPDATE=1` nếu muốn bỏ qua bước cập nhật ComfyUI.

```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/imageCreation.sh)"
```

## Outfit Transfer — Qwen Image Edit

Một lần chạy tải đủ Qwen Image Edit, Lightning LoRA, hai Outfit LoRA và OpenPose ControlNet cho workflow thay trang phục.

```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/outfitTransfer.sh)"
```

## zControlnet
```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/zFunControlNetUnion.sh)"
```

## ltx2
```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/thinh79/comfy-command-center/refs/heads/thinh/ltx2.sh)"
```
