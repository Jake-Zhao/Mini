# 05 · 时间、曝光与速度的严格定义

## 5.1 三种时间不可混用
1. 遥测采样时间：收到并验证读数的单调时间。用于新鲜度，不是动画时钟。
2. 仿真时间：本次有效前进距离`D += speed/3.6 * dt`。用于世界运动。
3. 虚拟快门：曝光时长。用于一帧中的运动积分，不等于屏幕刷新间隔。

100km/h → 27.777…m/s；在12.5ms快门内，环境行进约0.3472m。相同车速/快门下，30、60、120FPS只改变输出间隔，不改变这0.3472m。20km/h的位移是它的五分之一。

## 5.2 解析场景曝光积分
```pseudo
if speed is invalid, zero or reduceMotion:
    shutterDistance = 0
else:
    shutterDistance = speedMPS * exposureSeconds

N = 1 if shutterDistance == 0 else qualitySamples
color = 0
for i in 0..<N:
    t = ((i+0.5)/N - 0.5) * shutterDistance
    cameraRay = rayFromPixelAndCamera(pixel)
    intersection = analyticTunnelIntersect(cameraRay)
    color += shadeMaterialAndFilteredReflection(intersection, stationOffset:t) / N
```

反射灯与墙面灯在同一时刻重新采样。当前运动纹理记录的是曝光区间位移，不应直接当成逐帧速度或MetalFX运动纹理。

## 5.3 不同周期各自保留相位
不能对总路程统一取某个模数后再给任意周期纹理使用，否则会跳变。CPU保留Double总距离，对每个周期分别计算：

```text
phase(period) = positiveRemainder(totalDistance, period) / period
```

灯带、路标、路面、墙面、雾流/装饰各用独立周期。GPU只接收较小相位，避免大世界坐标浮点精度丢失。

## 5.4 状态表
| 输入 | 世界/文字雨/水雾推进 | 曝光模糊 | HUD/灯 |
|---|---|---|---|
| 有效0 | 停止 | 0 | 显示0；刹车独立 |
| 有效非零 | 米/秒推进 | 速度×固定快门 | 原始有效数值 |
| 暂停演示 | 冻结仿真相位 | 保留暂停瞬间外观 | 不让粒子/拖影突然消失 |
| 减少动态效果 | 停止所有装饰推进 | 0 | 数据仍可更新 |
| 速度失效/过期 | 停止，不预测继续加速 | 0 | 显示— |
| 后台/长间隔 | 不补算不可观察时间 | 恢复后重新计时 | 不把恢复跳跃当加速 |

渲染时钟从来不代替真实采样率。

## 5.5 伴行车辆
车与观察者相对位置固定，周围环境掠过；不让车无目的上下漂移。水雾从车轮附近发出，朝后低处衰退，使用同一个投影、场景深度和车体coverage。字形不进入时间历史、背景辉光或水雾层。

装饰左侧拖影只在数字左缘外侧绘制，没有对字形alpha进行拖拽复制；笔锋本身的纹理是静态材质，不作为时间残影。
