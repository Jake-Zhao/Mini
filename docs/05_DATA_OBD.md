# 05 · BLE / OBD 数据架构

视觉通过后接入。CoreBluetooth在App内scan/connect/discover/subscribe。ELM命令必须single-flight；通知可任意分片，以 > prompt成帧；每个响应带session epoch、monotonic timestamp、ECU来源和quality。

标准Mode01先做；supported PID目录按ECU发现。106项定义是解码范围，不是车辆实际支持保证。动画帧率与OBD采样频率分离。

Gear/brake若没有可信F56来源保持unknown。禁止clear DTC、actuator control、coding、flash和为了UI完成而盲扫私有UDS。
