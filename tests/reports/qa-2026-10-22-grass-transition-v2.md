# 2026-10-22 草地材质与色调二次优化

首版仅柔化边缘，用户仍能明显辨认草地交界。检查近景发现平原大圆叶颗粒、偏暗偏蓝的底色与横向条带和旧山脚不一致。

## 改动

- 内置image_gen参考当前山脚实景生成1254×1254细草v3，替代大圆叶颗粒；原稿、提示词、参考与SHA256均保留在`assets/map/dawn_wide_v3/`。
- 旧底色的大尺度明暗起伏降至30%，基调改为更接近山脚的灰绿；草叶细节继续通过重叠区最小色差拼合。
- 将草色和纹理分别处理：400世界像素模糊半径控制较宽范围的低频颜色匹配，150半径控制细节羽化。只对颜色低频匹配，不模糊最终草叶；原有保护遮罩限制最终写入。
- 连续底图、切片、预览和小地图同步重建。世界尺寸、八资源、导航、山区保护像素保持。

## 本轮验证

- 扩边24、大地图120项通过；日志`.codex-temp/qa-20261022-220402/`及`.codex-temp/qa-20261022-220406/`。
- GL Compatibility 38项（包含截图保存检查）通过，错误日志为空；三个视口、回城、小地图、重开、裁剪通过。日志`.codex-temp/grass-transition-v2-20261022/`。
- 目检全图、上中下段及1.6倍交界：平原大圆叶颗粒消失，条带减弱，山脚草色衔接更柔和；这不替代用户最终美术验收。
- `tools/check_wide_map.py`通过：9稿来源完整、61项确定性产物重建一致、18片地形重组、山区保护像素、原始源文件及导航保持。
- Godot导入、`tools/check_project.ps1`与`git diff --check`通过。

## 证据与来源

- [全图](images/grass-transition-v2-2026-10-22/960x540-full.png)
- [上段](images/grass-transition-v2-2026-10-22/join-3650-600.png)、[中段](images/grass-transition-v2-2026-10-22/join-4500-1500.png)、[下段](images/grass-transition-v2-2026-10-22/join-4500-2450.png)
- [最大倍率](images/grass-transition-v2-2026-10-22/grass-join-detail.png)
- [生成原稿](../../assets/map/dawn_wide_v3/grass-material-v3-source.png)、[完整提示词](../../assets/map/dawn_wide_v3/grass-material-v3-source.prompt.txt)、[来源清单](../../assets/map/dawn_wide_v3/generation-record.json)

原稿由内置image_gen生成，再由项目既有确定性素材工具接入；不是原生7K整图。最大倍率仍有源材质风格差异，最终观感待用户复核；不声称完全无缝。未重跑全量、未处理性能/动态避让/自然长局，未提交或推送。
