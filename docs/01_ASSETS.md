# 01 · 车辆素材与刹车状态合同

## 唯一的车身母版（锁定视角）
- `Source/Vehicle/car_master.png` 是唯一视觉母版，2172×724 RGBA。
- `Resources/Art/car_body.png` 是车身编译底图，1400×521。
- `Resources/Art/car_cruise.png` 和 `car_brake.png` **从同一个 car_body 以及同一个 brake_emission 遮罩生成**。
- 车身角度、投影、大小、轮胎、尾翼、车牌、背景透明度必须逐像素一致；差别只限两处尾灯内的颜色。
- 不允许再用两张不同角度的生成车图分别冒充行驶和制动状态。
- 车牌 `苏U K27D5` 由唯一车身母版承载，两态完全一致。

## 自动生成方法
`tools/build_assets.py` 执行 `build_car()`，随后执行
`tools/build_companion_states.py`，生成 `car_cruise.png` 和 `car_brake.png`。
`pack()` 将两者编译为 `linear-premultiplied-f16` 的 JTX2：`car_cruise.jtex`、`car_brake.jtex`。

可直接在 GitHub 查看被提交的两个源 PNG。大尺寸 JTX2 是可再生缓存，不提交仓库，每次运行编译器即可生成。

## 唯一的 Metal 投影
`JakeRenderer.swift` 仅根据可信 `HUDState.brakeOn` 选择一个材质：

```swift
let carTexture = hud.brakeOn ? brakeCar : environment[0]
let selectedEnvironment = [carTexture] + Array(environment.dropFirst())
```

两个状态共用 `u.carRect`、相机投影、接地阴影、道路、遮挡与雨雾管线。任何一帧只绘制**一辆车**。

`JakeShaders.metal` 不对制动灯二次增加相同的漫射亮度。尾灯正面亮度由 `car_brake` 纹理提供，额外 `brake_halo` 和 `brake_emission` 仅作为环境漏光和湿地反射。真实刹车状态未验证前，不能根据减速度猜测。

## 严格验证
`python3 tools/check_assets.py` 必须通过：
- 两图尺寸严格相同；
- 两图 alpha 矩阵逐像素相等；
- 刹车灯遮罩之外所有像素逐字节相等；
- 两者在遮罩内确有有效像素变化；
- JTX2 文件头、大小和预乘 alpha 数据均合法。

GitHub Actions `publish-companion-art.yml` 自动生成并提交
`Resources/Art/car_cruise.png`、`car_brake.png`、`car_body.png`、`brake_emission.png`、`brake_halo.png`。
