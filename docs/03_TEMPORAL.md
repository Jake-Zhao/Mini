# 03 · 时间 / 速度 / 曝光

```text
mps = speedKph / 3.6
deltaMetres = mps * dt
travel += deltaMetres
shutterDistance = mps * 0.0125
```

12.5ms虚拟快门与刷新率独立。100与20km/h在相同时间/曝光内的位移比为5。
dt<=0、dt>0.5s、paused、reduced-motion、invalid speed均不积分装饰运动。停车时brake仍可独立变化。

默认9个时间样本，33样本只作高成本参照；已经时间积分时禁止再做第二个完整运动模糊。
