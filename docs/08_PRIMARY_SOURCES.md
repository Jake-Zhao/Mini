# 08 · 原始技术来源与工具参考

核查日期：2026-10-25。以下用于支撑方法与API/格式事实；不意味着复制了样例代码、下载了贴图或执行了所有工具。实现中的美术尺寸/亮度/时效阈值是本项目决策。

| 来源 | 使用范围 |
|---|---|
| Apple MTLPixelFormat — https://developer.apple.com/documentation/metal/mtlpixelformat | 像素格式与sRGB/alpha处理 |
| Apple Metal资源指南 — https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Mem-Obj/Mem-Obj.html | sRGB采样解码与输出编码；不是手动两次gamma |
| Apple Metal sample code — https://developer.apple.com/metal/sample-code/ | 纹理、离屏通道、CPU/GPU同步和读取drawable的工具边界 |
| PBRT4 Camera Interface — https://pbr-book.org/4ed/Cameras_and_Film/Camera_Interface | 快门时间积分、相机空间与大坐标精度 |
| PBRT4 Textures and Materials — https://pbr-book.org/4ed/Textures_and_Materials | 材质角色和纹理采样；非用来认证本项目材质物理准确 |
| Blender Cameras — https://docs.blender.org/manual/en/latest/render/cameras.html | 透视与相机参数；本轮未运行Blender |
| Blender Alpha Over — https://docs.blender.org/manual/en/latest/compositing/types/color/alpha_over.html | 预乘合成方法 |
| Krita Transparency Masks — https://docs.krita.org/en/reference_manual/layers_and_masks/transparency_masks.html | 非破坏透明遮罩；本轮使用等价的编辑点/PNG合同 |
| Poly Haven license — https://polyhaven.com/license | 资产CC0与网站展示渲染/文案区别 |
| Poly Haven asphalt_02 — https://polyhaven.com/a/asphalt_02 | 3米尺度材质候选，未下载/未使用 |
| Poly Haven concrete_wall_001 — https://polyhaven.com/a/concrete_wall_001 | 1.5米尺度材质候选，未下载/未使用 |

不将未提供的车辆私有诊断ID写成事实；不把候选素材页中的效果图当可再分发的运行贴图。源照片由用户提供，包内处理并不自动授予第三方版权。
