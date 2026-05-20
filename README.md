# Blossom Grid — Core Feel Prototype

> 目标只有一个：**验证"一次合成是否足够舒服"。**

这不是完整游戏。没有关卡、没有 roguelike、没有任务系统。  
只有一件事：**滑动 → 合成 → 感受生长。**

---

## 项目结构

```
blossom-grid/
├── project.godot
├── scenes/
│   └── Main.tscn          # 场景：背景 + VBox + Board + Reset按钮
├── scripts/
│   ├── Main.gd            # 输入转发（方向键/WASD/R）
│   └── Board.gd           # 全部核心逻辑 + 动画 + 视觉
├── config/
│   └── tile_config.json   # 极简配置（bloom概率 + 生成权重）
├── tests/
│   └── board_logic_test.gd
└── assets/
    └── ui-preview.png
```

---

## 场景结构

```
Main (Control + Main.gd)
└── Background (ColorRect)        # 暖米色背景
└── VBox (VBoxContainer)
    ├── Title (Label)              # "Blossom Grid"
    ├── Subtitle (Label)           # "Slide gently. Watch things grow."
    ├── Board (Control + Board.gd) # 4×4 棋盘，全部逻辑在此
    ├── BottomRow (HBoxContainer)
    │   └── ResetButton (Button)   # "↺ new garden"
    └── Hint (Label)               # 操作提示
```

---

## 棋盘逻辑（Board.gd）

### 数据结构

每个格子：
```gdscript
{"value": int, "special": String}  # special = "none" | "bloom"
```

棋盘：`grid[y][x]`（Array of Array of Dictionary）  
视觉层：`tile_nodes[y][x]`（Panel 节点或 null）

### 合成流程

每次有效滑动：
1. `_slide_and_merge()` — 计算逻辑结果，返回 `tile_moves` / `merged_positions` / `bloom_positions`
2. `_run_move_animation()` — 异步驱动全部动画阶段（见下方）
3. 动画结束后 `is_locked = false`，接受下一次输入

---

## Bloom 逻辑

- 每个新生成的 tile 有 **12 %** 概率带 Bloom 标记（右上角粉色小圆点）
- Bloom tile 参与合成时：在合成位置**周围**随机萌发 1-2 个 seed（值为 2）
- 萌发动画：从小到大 + 透明渐显 + 微微上浮，像植物冒出土壤

---

## 动画系统

`_run_move_animation()` 按阶段顺序运行（async coroutine）：

| 阶段 | 内容 | 时长 |
|------|------|------|
| 1 · Slide | 所有 tile 节点 Tween 到新坐标 | 0.12 s |
| 2 · Reconcile | 释放被合并的节点，更新存活节点的视觉 | 即时 |
| 3 · Merge pulse | 合并目标 tile 轻微膨胀 → 回弹 | 0.22 s |
| 4 · Spawn | 新 tile 从小→大 + 透明渐显 | 0.36 s |
| 5 · Bloom burst | 若有 Bloom 触发，萌发 seed tiles | +0.08 s delay |

**棋盘呼吸：** Board 节点本身持续以 5 s 周期、0.3 % 幅度做缩放振荡，
给棋盘一种安静的"活着"的感觉。

---

## 生长阶段 & 颜色方案

| 数值 | 阶段 | 背景色 |
|------|------|--------|
| 2 | seed | 暖土棕 `#c8b090` |
| 4 | sprout | 嫩绿 `#acc882` |
| 8 | leaf | 叶绿 `#78aa68` |
| 16 | bud | 金黄 `#d4b870` |
| 32 | bloom | 暖橙 `#e89060` |
| 64 | flower | 玫瑰红 `#e07878` |
| 128 | petal | 薰衣草紫 `#cc8cd0` |
| 256 | drift | 天空蓝 `#88b8e8` |
| 512 | glow | 明黄 `#ece870` |
| 1024 | radiance | 琥珀 `#f8c858` |
| 2048 | ethereal | 乳白 `#fff4dc` |

棋盘背景：`#d4c8b4`（暖灰褐）  
空格槽：`#c0b8a8`（稍深）  
页面背景：`#eeeae1`（暖米色）

---

## 音效触发方案（当前为占位）

Board 预留 `MergeSfx`（AudioStreamPlayer）接口。  
风格参考：木头轻叩 · 水滴 · 风铃 · 玻璃摩擦  
触发点：
- 合成成功 → 短促木声
- Bloom 萌发 → 轻柔水声或风铃
- 新 tile 生成 → 极轻的纸张声

---

## UI 方案

极简三要素：
- **Board** — 游戏主体，占满中心
- **Reset 按钮** — 平铺式，低存在感（"↺ new garden"）
- **Hint** — 一行操作提示，字号小，颜色淡

无 HUD、无分数、无状态栏。

---

## 运行方式

安装 Godot 4.5.x，打开项目后运行主场景：

```
res://scenes/Main.tscn
```

| 输入 | 动作 |
|------|------|
| Arrow keys / WASD | 滑动 |
| R | 重新开始 |

---

## 测试

```bash
godot --headless --path . -s res://tests/board_logic_test.gd
# 若命令名为 godot4：
godot4 --headless --path . -s res://tests/board_logic_test.gd
```

测试覆盖：
- 基本滑动 + 合并
- `tile_moves` 追踪（from/to/consumed）
- Bloom 触发位置记录
- 无效移动检测（已压紧、不同值）
- 合并目标值验证

---

## 验证"舒服感"

**通过标准：**

1. 做第一次合成时，感觉是"这个东西长大了"，而不是"数字变了"
2. 合成动画（膨胀→回落）让人下意识想再做一次
3. Bloom 萌发时，感觉像植物真的在生长
4. 可以不看数字，只看颜色和形状感受成长节奏
5. 棋盘在静止时也感觉是"活的"（呼吸感）

**失败标准：**

- 动画感觉太快、太硬、太"数据"
- 看不出 seed → flower 的色彩旅程
- 停下来等动画结束时感觉烦躁而非平静
