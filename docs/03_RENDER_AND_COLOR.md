# 03 · 渲染、空间与颜色契约

## 3.1 空间只有一套
相机相对坐标：x向右、y向上、z向前；世界距离单位米。UV原点左上。固定针孔相机：

```text
aspect = outputWidth / outputHeight
u = 0.5 + x / (2 * tanHalfFov * aspect * z)
v = horizon - (y - eyeHeight) / (2 * tanHalfFov * z)
```

`Core/SceneGeometry.swift`与`Shaders/SceneCore.inc`使用同一公式。当前相机参数是艺术选择，不是现实隧道测量。隧道是解析壁面，不是导入的高精度建筑模型。

车辆是固定视角照片替身。车辆代理尺寸只用于当前镜头投影，不应被解释为MINI真实几何尺寸。局部接地锚点投影到地面后反推出矩形，不能再按“屏幕右下角80%”随意放车。

相机匹配约束和艺术构图可能冲突：当前选固定视角代理，限制摄影机不绕车；不假装已经恢复真实车身几何。车体倒影是有标注的固定视角近似。

## 3.2 色彩与alpha
所有计算以linear sRGB为工作空间；内部HDR为rgba16Float。它不是ACEScg/ACES完整管理管线。filmic函数只是项目级曲线，不等于ACES认证输出变换。

| 输入 | 存储/加载 | 允许操作 |
|---|---|---|
| 基础色PNG | sRGB RGBA8 | 采样解码后做线性计算 |
| 法线/粗糙度/湿润度 | linear RGBA8 | 不做sRGB转换 |
| 透明PNG母版 | straight alpha，RGB为sRGB | 只作为编辑/检查与资源编译源 |
| 透明运行纹理 | RGBA float16，linear premultiplied | 先预乘再过滤，mipmap在线性预乘数据上生成 |
| HDR中间结果 | rgba16Float linear | 颜色/曝光/辉光 |
| 最终drawable | bgra8Unorm_srgb | shader输出线性；由格式编码一次 |

```text
linearRGB = decode_sRGB(sourceRGB)
premulRGB = linearRGB * alpha
sampled = bilinear_or_mip_filter(premulRGB, alpha)
resultRGB = sampled.rgb + backgroundRGB * (1 - sampled.alpha)
```

不能把`sampled.rgb`再乘alpha；不能把已线性预乘数据交给sRGB像素格式再次解码。格式和载荷长度必须匹配，缺资产应报错，不使用空白图替代伪成功。

## 3.3 材料不等于颜色滤镜
道路/墙面数据将normal、roughness、wetness角色分开。法线由带实际tile尺度的高度梯度生成；采样恢复Z，参与表面方向。道路采用受控水膜Fresnel近似。

这是受控层状近似，不是完整BRDF多次散射、路径追踪或严格测量材料。粗糙反射使用稳定方向采样，不逐帧抖随机噪声。灯具HDR强度、雾密度属于艺术常数。

## 3.4 帧图
机器文件：`Config/render_graph.json`。目标执行：

```text
Scene HDR + depth / normal / roughness / wetness / object-id / exposure-motion
  → wet-road lighting & filtered reflections
  → vehicle + contact integration
  → binary rain / spray / mist
  → exposure integration
  → controlled bloom / filmic tone map
  → left-side speed accent
  → hero glyphs and gear at output resolution
```

主数字不进入背景后期。未来若接入MetalFX，必须新增真实逐帧运动/抖动/遮挡/历史失效合同，不复用当前“曝光区间位移”冒充。

## 3.5 参数变更边界
相机、光学、车辆锚点和HUD参数来自配置与共享代码。修改材质尺度或相机参数时，必须同步检查CPU与shader实现并重新运行测试；不能只改JSON就宣称shader会自动跟随。

## 3.6 约束不是承诺
高样本曝光积分与多方向反射有实质计算成本。高样本参照模式只用于诊断，不承诺60FPS。相机、色彩、字形不因质量档位更换；可降低内部背景尺寸/样本数/粒子数。所有帧率和热行为都需后续Apple平台测量。
