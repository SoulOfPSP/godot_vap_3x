# Godot VAP 3.x

> 面向 Godot 3.x 的 Tencent VAP v2 / VAPX 播放器，支持透明动画、动态头像、图片和文字融合。

![Godot](https://img.shields.io/badge/Godot-3.x-478CBF?logo=godot-engine&logoColor=white)
![Tested](https://img.shields.io/badge/Tested-3.5.3-success)
![Platform](https://img.shields.io/badge/Windows-x86__64-0078D4?logo=windows)

## 功能一览

| 功能 | 状态 | 说明 |
|---|---:|---|
| 普通 VAP | ✅ | RGB 与 Alpha 画面在 Godot shader 中合成 |
| VAPX | ✅ | 运行时传入头像、图片和文字 |
| 内嵌 `vapc` | ✅ | 直接从 MP4 顶层 box 读取配置 |
| 外部 JSON | ✅ | 可显式指定，也支持伴随配置文件 |
| 逐帧遮罩 | ✅ | `frame`、`mFrame`、`mt=0/90`、`z` |
| 图片适配 | ✅ | `fitXY`、`centerFull` |
| 播放控制 | ✅ | 播放、暂停、恢复、停止、逐帧 seek |
| MP4 音轨 | ✅ | Media Foundation 增量解码，`AudioStreamGenerator` 流式播放 |

## 项目关系

Godot 3.x 版本现在拆成两个独立 addon：

```text
addons/
├── godot_vap/               VAP 格式、透明合成、VAPX 动态融合
└── godot_mp4_decoder/       通用 H.264 MP4 → RGBA8 GDNative 解码器
```

独立解码器源码位于仓库根目录 [`godot_mp4_decoder_3x`](../godot_mp4_decoder_3x)。它不理解 VAP，只负责打开普通 MP4、顺序解码、seek 到开头并返回 RGBA 字节；因此可以被其他 Godot 3.x 项目单独使用。

## 依赖与兼容性

- Godot 3.x；当前二进制使用 Godot `3.5` 分支的 `godot-cpp` 编译，并已在 Godot `3.5.3` 验证。
- Windows x86_64。
- Windows Media Foundation：系统组件，用于 H.264/MP4 解码。
- `libwinpthread-1.dll`：随插件包一起提供。
- 不依赖 FFmpeg，不需要安装 codec 包。
- Godot 3.x 的 GDNative ABI 对小版本兼容不如纯 GDScript 稳定；若低版本 3.x 无法载入 DLL，请按独立解码器 README 使用目标版本 headers 重新编译。

## 安装

使用插件包时，把压缩包中的 `addons` 整体复制到目标项目：

```text
your_project/
└── addons/
    ├── godot_vap/
    └── godot_mp4_decoder/
```

在 **Project → Project Settings → Plugins** 中同时启用：

1. `Godot MP4 Decoder 3.x`
2. `Godot VAP 3`

缺少 `godot_mp4_decoder` 时，`vap_player.gd` 会因无法 preload `mp4_decoder.gdns` 而加载失败。

## 最小用法

添加一个 `Control` 节点并挂载：

```text
res://addons/godot_vap/vap_player.gd
```

然后：

```gdscript
func _ready():
    $VAPPlayer.enable_audio = true
    $VAPPlayer.connect("animation_ready", self, "_on_vap_ready")
    $VAPPlayer.connect("animation_error", self, "_on_vap_error")
    $VAPPlayer.load_vap_video("res://effects/gift.mp4")

func _on_vap_ready(_config):
    $VAPPlayer.play()

func _on_vap_error(message):
    push_error(message)
```

`res://` 会在播放器内部通过 `ProjectSettings.globalize_path()` 转为 Media Foundation 需要的绝对路径。

## 动态头像与文字

```gdscript
func _ready():
    $VAPPlayer.connect("fusion_resource_needed", self, "_on_resource_needed")
    $VAPPlayer.connect("animation_ready", self, "_on_vap_ready")
    $VAPPlayer.load_vap_video("res://effects/gift_vapx.mp4")

func _on_resource_needed(resource_id, resource_type):
    if resource_type == "txt":
        $VAPPlayer.set_fusion_resource(resource_id, "玩家昵称")
    else:
        $VAPPlayer.set_fusion_resource(resource_id, preload("res://avatar.png"))
```

文字接受 `String`；图片接受 `Texture` 或 `Image`。播放途中可以再次调用 `set_fusion_resource()` 更新内容。

## 公共 API

| API | 用途 |
|---|---|
| `load_vap_video(path, config_path = "")` | 读取 VAP 配置并打开 MP4 |
| `play()` / `pause()` / `resume()` / `stop()` | 播放控制 |
| `seek_to_frame(frame)` | 从头解码到目标帧 |
| `set_fusion_resource(id, data)` | 设置文字、Texture 或 Image |
| `get_fusion_source_config(id)` | 查询 `vapc.src` 声明 |
| `get_playback_info()` | 当前帧、帧率、尺寸和融合状态 |

信号与 Godot 4 版保持一致：`animation_ready`、`animation_started`、`animation_finished`、`animation_error`、`frame_changed`、`fusion_resource_needed`、`fusion_resource_ready`。

## 运行 Demo

用 Godot 3.5.3 打开本目录并运行主场景：

- “普通 VAP”播放 `demo/video.mp4`。
- “VAPX 动态融合”播放 `demo/vapx.mp4`。
- VAPX demo 会注入绿色头像和 `Godot VAP` 文字。
- `demo/video.mp4` 本身没有音轨；要验证声音请选择带音轨的 `demo/vapx.mp4`。

## 音频说明

播放器支持直接播放 MP4 内的音轨。addon 默认保持 `enable_audio = false`，避免接入旧项目后突然发声；需要声音时在 Inspector 或代码中开启。Demo 已默认开启。

实现上没有让音频和视频争用同一个顺序解码器：视频和音频分别使用独立的 Media Foundation `SourceReader`，音频以 Float PCM 小块持续喂给 `AudioStreamGenerator`。这和 GoZen 的核心思路一致——分离解码上下文并流式消费——只是 Godot 3.x Windows 版后端使用 Media Foundation，而不是 `AudioStreamFFmpeg`。

## 当前边界

- 当前预编译 DLL 只支持 Windows x86_64。
- Media Foundation 能否播放某种 MP4 取决于系统可用解码器；重点验证格式为 H.264。
- seek 是“回到开头并顺序解码到目标帧”，适合短特效，不适合超长视频随机拖动。
- RGBA 帧由 CPU 解码并上传纹理，定位是短 VAP 动画而非通用高码率播放器。
