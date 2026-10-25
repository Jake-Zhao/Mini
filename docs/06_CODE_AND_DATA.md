# 06 · 具体代码与数据接入

## 文件映射
| 模块 | 文件 | 当前责任 |
|---|---|---|
| 源数据合同 | `Core/Sources/JakeCore/Telemetry.swift` | 来源、epoch、新鲜度、三态刹车、未知挡位 |
| 世界/演示时钟 | `Core/.../Motion.swift` | 米单位积分、暂停、质量档位、明确模拟序列 |
| 相机与相位 | `Core/.../SceneGeometry.swift` | 投影/反投影、车的接地、按周期计算相位 |
| HUD几何 | `Core/.../Layout.swift` | 全字形可见边界居中、角标避让 |
| 运行参数 | `Renderer/SceneSettings.swift` | 从包内配置读相机/光学/车辆/HUD |
| 资源载入 | `Renderer/TextureStore.swift` | 载荷长度/格式/sRGB校验，线性预乘mipmap |
| 绘制调度 | `Renderer/JakeRenderer.swift` | 资源环、渲染顺序、生命周期、截图和质量模式 |
| 空间光照 | `Renderer/Shaders/SceneCore.inc` | 解析隧道、材质、反射、曝光积分、投影 |
| 合成/颗粒/HUD | `Renderer/Shaders/JakeShaders.metal` | 车/雨/接地/水雾/后期/字形 |
| 数据布局 | `RenderTypes.swift`与`ShaderTypes.h` | CPU/GPU共享uniform布局 |
| 控制台 | `App/` | DEMO、速度、刹车、图层和参考开关 |

## 数据解析不由shader做
```pseudo
snapshot = mailbox.readImmutableSnapshot()
hud = snapshot.resolve(monotonicNow)
speed = hud.validSpeedOrNil
phase = motionClock.advance(dt, speed, paused, reduceMotion)
uniforms = settings + phase + camera + validatedBrake + quality
render(uniforms, hud)
```

真实“D几”只有选择器/前进档位语义都可信才可显示。刹车unknown≠released；画面在unknown下不点亮刹车灯，但调试状态仍记unknown。停车不自动清除可信刹车信号，减速不自动置pressed。

## BLE边界保持明确
Core Bluetooth app内扫描/连接路线保留，但当前仓库的第一里程碑不是BLE。未来接入仍要求：一个ELM请求在途、任意分片重组、提示符边界、超时/迟到epoch隔离、按ECU支持位图发现、只读诊断。不得为点亮刹车灯随意扫描未知厂商命令。

不包含通用OBD能读取本车制动开关/真实挡位的保证。真实输入尚缺时使用Unavailable通道；演示来源始终标DEMO。

## 执行顺序
1. 阅读本仓库入口与运行约定。
2. 运行`tools/build_assets.py`与`tools/verify.py`。
3. 运行Core测试。
4. 在Apple平台构建PURE渲染器并产出规定的视觉证据。
5. 视觉通过后再接入BLE。

## 定位限制
当前优先完成PURE渲染基线。FULL/FOCUS、连接设置、记录回放和诊断页面的产品范围没有取消，但不应在视觉基线未通过前抢先扩展。
