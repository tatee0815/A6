# Tank Battle 3D - BTL5 🚀

![Godot Engine](https://img.shields.io/badge/Godot-4.6-%23478cbf?logo=godot-engine&logoColor=white)
![Status](https://img.shields.io/badge/Status-Development-orange)

Một trò chơi chiến đấu xe tăng 3D đầy kịch tính được phát triển trên nền tảng **Godot Engine 4.6**. Dự án này tập trung vào trải nghiệm chiến đấu góc nhìn thứ ba, tích hợp hệ thống mạng (multiplayer) và các tính năng tương tác đa dạng.

## ✨ Tính năng nổi bật

- **🎮 Điều khiển mượt mà:** Hệ thống điều khiển xe tăng 3D trực quan (W/A/S/D).
- **💥 Cơ chế chiến đấu:** Bắn đạn pháo với hiệu ứng vật lý và âm thanh sống động.
- **🌐 Multiplayer:** Hỗ trợ kết nối mạng thông qua `NetworkManager`.
- **⏸ Pause Menu:** Hệ thống tạm dừng trò chơi, thoát về menu chính hoặc thoát game.
- **🛠️ Debug & Cheats:** Tích hợp sẵn các công cụ hỗ trợ phát triển (Cheat mode).
- **🎨 Đồ họa hiện đại:** Sử dụng Forward+ renderer và MSAA 2x để tối ưu hóa hình ảnh.

## 📁 Cấu trúc thư mục

```text
A6/
├── .godot/           # Dữ liệu nội bộ của Godot (đã được ignore)
├── scenes/           # Chứa các file cảnh (.tscn) của trò chơi
├── scripts/          # Chứa logic xử lý (GDScript)
├── project.godot     # File cấu hình chính của dự án
└── README.md         # Tài liệu hướng dẫn
```

## 🚀 Hướng dẫn cài đặt

1. **Yêu cầu:** Tải và cài đặt [Godot Engine 4.x](https://godotengine.org/download).
2. **Clone project:**
   ```bash
   git clone https://github.com/tatee0815/A6.git
   ```
3. **Mở dự án:**
   - Mở Godot Engine.
   - Chọn **Import**.
   - Tìm đến folder `A6` và chọn file `project.godot`.

## 🕹️ Phím điều khiển

| Hành động | Phím |
| :--- | :--- |
| Di chuyển tiến | `W` |
| Di chuyển lùi | `S` |
| Quay trái | `A` |
| Quay phải | `D` |
| Quay đầu trái | `Q` |
| Quay đầu phải | `E` |
| Bắn | `Space` |
| Bật/Tắt Cheat | `C` |
| Tạm dừng (Pause) | `Esc` |

## 🛠️ Công nghệ sử dụng

- **Engine:** Godot 4.6
- **Ngôn ngữ:** GDScript
- **Rendering:** Forward+
- **Network:** ENetMultiplayerPeer (thông qua NetworkManager)

---