# Waiting for Dawn（等待黎明）

一款面向微信小游戏的2D像素卡牌塔防游戏。玩家在持续十波的黑夜中经营聚落、构筑防线、收集怪物王对策并守住主城。

## 当前阶段

项目处于技术准备阶段，已完成：

- 核心玩法、单夜十波、克制、怪物王、黄金凤凰和广告商业化GDD。
- Godot 4.7开发验证环境；微信导出最终版本待复核。
- 960×540横屏兼容渲染配置。
- 全局对局状态与可启动的灰盒入口场景。

下一目标是实现第1波敌人移动、攻击主城和失败结算。

## 开发环境

- Godot 4.7 Standard（当前开发验证）
- GDScript
- GL Compatibility渲染器
- Windows开发，微信小游戏首发

当前工程已由Godot 4.7-stable打开并通过首个场景测试。微信导出所用编辑器、PCK和WASM模板必须保持同一补丁版本；在导出技术验证完成前不接入平台插件。

## 本地运行

1. 使用Godot 4.7 Standard打开当前开发工程。
2. 在Godot项目管理器中导入本仓库根目录。
3. 打开项目后按F6/F5运行主场景。

若Godot已加入PATH，可执行：

```powershell
godot --path . --editor
```

工程结构冒烟检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_project.ps1
```

## 目录

- `design/gdd/`：游戏系统设计。
- `docs/project/`：技术偏好和预算。
- `docs/architecture/`：技术决策记录。
- `production/`：项目状态与后续开发故事。
- `src/core/`：全局状态与纯规则。
- `src/main/`：入口场景。
- `tools/`：本地检查工具。

## 微信小游戏说明

首个灰盒不接入第三方导出插件、广告或排行榜SDK。核心循环稳定后，再单独验证微信WASM模板、包体、音频、存档、排行榜与激励广告桥接。
