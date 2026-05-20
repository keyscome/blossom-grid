# Blossom Grid (Godot 4.x MVP)

一个「放松型、无限成长、数字自然演化」独立游戏 MVP。

> 目标不是“刺激”，而是“舒服”。

## 1) 项目结构

```
/home/runner/work/blossom-grid/blossom-grid
├── project.godot
├── scenes
│   └── Main.tscn
├── scripts
│   ├── Main.gd
│   └── Board.gd
├── config
│   └── tile_config.json
├── tests
│   └── board_logic_test.gd
├── assets
│   └── ui-preview.png
└── README.md
```

## 2) 场景结构

- `Main.tscn`
  - `Main (Control)`
    - `Background (ColorRect)`
    - `VBox (VBoxContainer)`
      - `Title (Label)`
      - `Subtitle (Label)`
      - `Board (Control + Board.gd)`
      - `Hint (Label)`

## 3) 核心代码

- `Main.gd`：输入转发（方向键 / WASD）
- `Board.gd`：
  - 4x4 棋盘模型
  - 滑动 + 合成（2048 风格）
  - 无限模式（无失败惩罚，仅无可动时等待自然涌现）
  - 特殊块系统（Bloom/Moss/Flow/Echo）
  - 柔和绘制（暖色、低饱和）

## 4) 棋盘逻辑

- 固定 `BOARD_SIZE = 4`
- 每次有效滑动后：
  1. 线性压缩
  2. 同值合成
  3. 处理特殊块后效
  4. 被动特性更新
  5. 生成新块

## 5) 合成逻辑

- 同值块合成为双倍值
- `merge_delta` 记录本轮合成增量（供 Echo 使用）
- Bloom 参与合成会额外生成低级块

## 6) 特殊块系统

- **Bloom**：合成触发后额外生成一个 `2`
- **Moss**：每轮缓慢提升一个邻居（数值翻倍）
- **Flow**：每轮尝试缓慢移动并推动链条
- **Echo**：在发生合成后，复制一次邻近“升级”效果

## 7) 动画系统（MVP）

当前为轻量方案：
- 低对比暖色块面
- 柔和圆角与文字提示

> 下一步可接入 Tween（缩放脉冲、位移动画）与轻音效总线。

## 8) 数据结构

每个格子为字典：

```gdscript
{"value": int, "special": String}
```

棋盘为 `Array[Array[Dictionary]]`。

## 9) JSON 配置

`config/tile_config.json` 驱动：
- 出生数值池 `spawn_values`
- 特殊块权重 `special_weights`
- 特殊块颜色 `special_colors`

## 10) 测试方案

仓库当前没有现成 Godot CI/测试基建，MVP 使用以下聚焦验证：

- 自动化脚本测试（在 Godot 4.x 环境执行）：
  - `godot --headless --path . -s res://tests/board_logic_test.gd`（若本机命令名为 `godot4`，请替换为 `godot4`）
- 手动功能测试：
  - 四方向滑动与同值合成
  - Bloom/Moss/Flow/Echo 行为触发
  - 长时间游玩稳定性（无限成长）
- 配置测试：
  - JSON 可解析
  - 权重总和 > 0

## 11) 运行方式

在本机安装 Godot 4.5.1（或兼容 4.5.x）后：

1. 打开项目目录
2. 运行主场景 `res://scenes/Main.tscn`
3. 使用方向键或 WASD 操作

## UI 预览截图

- `assets/ui-preview.png`（当前沙箱无 Godot 运行时，故提供同风格 MVP mockup 截图）

## 12) 后续扩展建议

- 加入真实 Tween 动画与柔和音效层
- 增加“生态事件”（季节、雨露）作为低压力随机变化
- 增加可选“冥想 UI 模式”（隐藏数字，仅显示成长节奏）
- 增加存档与长期花园演化统计
