# 00 · 最终决策

- iPhone-only；横屏左右；PURE默认。
- Hero speed可见轮廓正中；无km/h、无转速、无参数卡、无米字旗、无常驻导航。
- Gear小徽标位于speed右下；车辆小且位于右下道路。
- 视觉基准：Reference/APPROVED.png；只能更好，不能退化。
- 原生SwiftUI + MTKView + Metal。WebView/HTML不属于产品路径。
- 上半部二进制雨实际来源为“一路平安”的UTF-8 bits。
- 0km/h停止所有装饰运动；速度驱动空间运动和曝光位移。
- Speed/Gear最后全分辨率绘制，永不进入背景blur/DOF/bloom/history。
- 真实gear/brake未知就保持unknown，不推断。
