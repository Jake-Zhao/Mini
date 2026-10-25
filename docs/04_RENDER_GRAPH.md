# 04 · Metal Render Graph

1. Scene/G-buffer：scene HDR；motionDepth(xy shutter displacement / z axial depth / w surface id)；material(roughness/wetness/object id)。
2. Exposure/motion：默认时间积分；非积分路径才允许gather blur。
3. Optional far DOF：默认关，背景专用。
4. Environment：binary rain → contact → car → proxy reflection → brake emission/halo。
5. GPU spray：移动时启用，必须深度/车体silhouette rejection。
6. Bloom：环境quarter-res，可热降级关闭。
7. Tone map：ACES-like→sRGB drawable。
8. Sharp HUD：left streak→badge→speed→gear，全分辨率。

Debug必须保留Beauty/Depth/Motion/Roughness/Wetness/ObjectID。
