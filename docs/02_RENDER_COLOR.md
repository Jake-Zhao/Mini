# 02 · 色彩 / 透明 / 镜头

- HDR中间目标：linear sRGB，RGBA16F。
- sRGB纹理仅由Metal像素格式做一次decode。
- 透明sprite：linear-light premultiplied；blend ONE / ONE_MINUS_SOURCE_ALPHA。
- 最终drawable：BGRA8Unorm_sRGB；tone mapper不再手动gamma。

镜头：tanHalfVerticalFOV=0.30，eyeHeight=1.22m，horizon=0.61H，tunnelHalfWidth=6.5m，archHeight=4.2m。
车辆代理(x=3.50,z=8.00,width=1.65m)。这些是美术空间参数。
