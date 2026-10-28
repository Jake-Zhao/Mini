# JAKE DRIVE — Luna 唯一实施指令（2026-10-28）

只使用 https://github.com/Jake-Zhao/Mini 的最新 main。不要从旧 ZIP 覆盖代码或资产。先 `git pull --ff-only`，然后阅读 `START_HERE.md`、`docs/01_ASSETS.md`、`Config/scene.json`、`Core/Sources/JakeCore/SceneGeometry.swift`、`Renderer/JakeRenderer.swift`、`Renderer/Shaders/JakeShaders.metal`、`tools/build_assets.py` 和 `tools/check_project.py`。

## 第一道强制验收：数字字形不得混搭

截图中出现 "1、8 是白色普通笔画，2 是图片裁切，7/2 与其他数字不同" 属于硬性不通过。

- 现在生成器对所有 `0123456789DNPR-` 字形统一执行 `path_mask(g) → distress → 统一材质 → glyph_atlas`，不存在任何 `approved_glyph()` 例外或以 72 图片作为运行素材的路径。
- 运行 `python3 tools/build_assets.py`（使用已提交的真实 source masters），检查 `Resources/Art/glyph_atlas.png` 中每个数字的样式一致，再运行 `python3 tools/check_project.py`、`python3 tools/check_assets.py`。
- 先单独在完全黑底显示 `0 1 2 3 4 5 6 7 8 9`，以及 `72/88/128/100/D3`，以同一像素尺寸截图。不得因为截图中 72 的旧笔锋更炫而偷偷重新引入混合体系。
- 编译后的 `Resources/Art/glyph_atlas.jtex` 必须由新 `glyph_atlas.png` 重新生成。禁止沿用旧构建目录里的缓存；清理派生资源后再构建。
- 保持数字主体清晰，不施加背景 blur／motion blur／景深；左侧速度能量属于背景独立层。默认 PURE 绝不显示 `km/h` 或转速。

## 第二道强制验收：汽车不能飞

当前车辆代理按 approved 主视觉中的照片裁剪并投影。统一透视参数定义在 `Config/scene.json`：`tanHalfVerticalFOV=.30, eyeHeight=1.22, horizon=.61, tunnelHalfWidth=8.5m`，车 `x=5.77m, z=13m, proxyWidth=3.61m, contactY=.806`。对应 approved 的 1774×887 画面车框必须在 `(1330,470,410,260)` 附近。

- 同一母版导出 `car_cruise/car_brake/car_wake/contact_shadow/brake_emission/brake_halo`。车正常/刹车两态 alpha、位置、角度、轮胎、车牌、尾翼完全相同，只允许尾灯变亮。
- 两处轮胎接地点来自 approved 画面 `(1398,659)` 和 `(1532,675)`。环境 compositor 的接地阴影/喷溅/倒影只允许在 G-buffer 的**道路**区域出现，不得透到墙、天空或 HUD。
- 相机视角/道路宽度必须支持整个车体，测试拒绝车辆越过隧道墙。不得仅通过垂直平移 Sprite 使它看起来贴地；轮胎必须真的触到道路透视平面。
- 0 km/h 不应出现新喷溅；车与本车同速伴行，相对屏幕位置基本稳定；真实刹车信号未确认，只有明示 DEMO 开关能控制亮刹车灯，不得从减速猜刹车。
- 注意：这些是**同镜头照片代理 + 程序粒子**，不是完整 3D 轮胎／水体流体模拟。若实际照片不足以支撑真实效果，明确 NOT ACCEPTED；不可用绿色随机线代替物理喷溅。

## 构建与视觉证据

按顺序：
1. `python3 -m pip install -r tools/requirements.txt`
2. `python3 tools/build_assets.py`
3. `python3 tools/check_assets.py && python3 tools/check_project.py`
4. `swift test --package-path Core`
5. 在 Mac 运行 Xcode 项目，清掉 DerivedData 和旧 .jtex；先用独立背景/车辆/字形层截图做对照，再组合。
6. 输出实际 Metal drawable 的截图，至少 `0, 72, 88, 100, 128` + 正常/刹车两态 + 透明车身/checkerboard + 只显示路面/深度与车辆接地层。禁止用 AI 概念图替代程序实输出。
7. 对比用户 approved：数字系统统一、车轮贴地、湿路反光方向、影子与水花的位置和动态合理。以上任意一项失败即停止继续开发 BLE，并修复对应生产链。

项目仍不是实车验收完成品。不得把 GitHub CI 通过写成 iPhone 画质通过。最终输出实际命令、测试日志、原生截图与仍未通过的审美项。
