# 01 · 素材合同

## 车辆
- Source/Vehicle/rear_original.png：用户原始后侧照片，姿态/来源记录。
- Source/Vehicle/car_master.png：2172×724 RGBA批准透明车母版，实际运行品质来源。
- Resources/Art/car_body.png：1400×521编译图。
- brake_emission / brake_halo：仅尾灯显式区域。
- contact_shadow：接地辅助。

禁止按亮度阈值重新抠车。运行sprite在线性空间预乘alpha后存为JTX2。

## 数字
0–9、D/N/P/R/— 全部属于JAKE PERFORMANCE BRUSH体系；7/2从批准图笔锋抽取，其余以同倾角、笔锋重量、破边规则生成。Resources/Config/glyphs.json是唯一度量来源。禁止系统字体替代。

## 材质
asphalt_color/surface、concrete_color/surface、flow_noise由固定seed生成。surface通道是数据纹理，不标sRGB；不是摄影扫描PBR。
