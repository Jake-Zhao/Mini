# 07 · Luna执行协议

不要重设计。先读DESIGN_MASTER.md、批准图和素材审计，再编译现有工程。

顺序：
1. 运行离线生成/测试。
2. 在Mac/Xcode修真实编译问题，不改设计掩盖错误。
3. iPhone 15 Pro DEMO验证0/20/72/88/100/128、gear、brake、debug G-buffer。
4. 视觉未达到批准图，不进入BLE。
5. 视觉通过后实现LiveTelemetrySource和CoreBluetooth/ELM。

性能降级：背景分辨率→采样/blur→particles→bloom→fps。HUD最后，不降低清晰度。所有未执行项写NOT RUN。
