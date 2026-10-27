# 01 · 批准镜头中的伴行车辆素材合同

## 为什么原来的车会浮在路面上
旧 `Source/Vehicle/car_master.png` 是独立棚拍式固定角度车图，和批准图的道路相机没有共同拍摄投影。即使在代码里放一个阴影，也不能让不同视角变成同一视角。

当前唯一生产路径：
1. `Reference/APPROVED.png` 是用户批准的 1774×887 湿路面镜头；
2. `tools/build_road_car_from_approved.py` 从该镜头的固定区域 `[1300,480,1725,745]` 提取车身和轮胎压水；
3. 生成同一透明覆盖下的 `car_body / car_cruise / car_brake`（1050×655）；
4. `car_wake` 保存该镜头原本的湿地轮胎喷溅，运动时混合，停车时不新增水花；
5. `contact_shadow` 为轮胎接地点锚定的道路阴影；
6. `brake_emission / brake_halo` 只控制尾灯及道路红色漏光；**车的姿态不变**。

`Source/Vehicle/car_master.png` 和 `rear_original.png` 仍作为原始素材归档；**不再参与 iPhone PURE 运行时车辆的构图或贴图生成**。不再切换两张不同视角的独立照片。

## 同镜头与接地点
渲染时：
- 车辆前轮参考点：原图 (1399,672)
- 车辆后轮参考点：原图 (1501,697)
- 尾部/后景反光参考点：(1701,693)
- Runtime 画布：1050×655；约定接地锚点相对高度 `0.82`
- Scene shot `x=4.3 m, z=10.0 m, proxyWidth=2.35 m`，均为美术镜头标定，不是车辆实测几何
- 前后轮沿道路地平线朝中心消失点收敛，不允许用不匹配的矩形影子冒充接地

`u.carRect` 是唯一位置与缩放数据。所有车身纹理、压水、刹车灯、接地阴影和倒影使用同一个矩形／相机投影。两种刹车状态唯一差异在尾灯 RGB，Alpha、轮胎、车牌和水花的像素一致。

## 道路合成（不是整张贴图随机飘）
Metal `environmentFragment` 按顺序：
1. 在轮胎接地点的地面坐标做吸收式 AO（`contact_shadow`）；
2. 使用湿路面材质扰动采样同镜头车身倒影；仅从轮胎接地线以下出现，刹车仅改变尾灯反光；
3. 当且仅当车速有效且不为零，低强度合成来源照片中的 `car_wake`；
4. 最后渲染 `car_cruise` 或 `car_brake`，始终只出现**一辆车**。

喷雾的随机 GPU 粒子仅作少量深度辅助，核心轮胎水花来自同镜头实际美术资产。它仍属于**照片投射/代理反射**，不是已经做出的完整液体动力学求解或真实车辆三维扫描。

## 可重建性和自动验收
运行 `python3 tools/build_assets.py` 生成 14 组 PNG/JTX2 纹理，并通过 `python3 tools/check_assets.py`：
- 新生成车图三态尺寸都是 1050×655；
- `car_cruise` 与 `car_brake` Alpha 完全相同；
- 任何 RGB 变化都必须在显式尾灯遮罩内；
- `car_wake` 非空、和 `car_body` 一样大小；
- `contact_shadow` 非空，不能在车身内部造黑洞；
- 车的相机与配置与 `runtime_registration.json` 一致。

`.github/workflows/publish-companion-art.yml` 会把运行 PNG（除大型 JTX2 缓存）及注册数据上传 GitHub。非车辆素材、已确认的数字/隧道资源保持原样。

## 视觉验收与风险
GitHub Actions 成功**只能证明注册、生成和格式正确**。必须在 iPhone 上用实际 Metal 出图做同尺寸画面对照。照片镜头资产不能在大幅改变视角时产生真实新侧面；如果以后要任意转动相机，应改用实拍多视角或合格 3D 模型，不能硬扭 2D 图。
