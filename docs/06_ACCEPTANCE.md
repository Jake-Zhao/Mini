# 06 · 验收

## 离线合同
- swift test --package-path Core
- python3 tools/build_assets.py
- python3 tools/verify_final.py

## 真机阶段（本轮NOT RUN）
必须提交0/72/100实际drawable截图；Beauty/Depth/Motion/Roughness/Wetness/ObjectID；10分钟以上帧时/热状态；brake on/off；进入后台/恢复。

硬失败：车体缺块/白边；speed被模糊；0仍滚动；帧率改变曝光长度；gear/brake被猜测；用概念图代替原生输出。

工程测试通过不等于审美通过。Reference/APPROVED.png是最低美术门槛。
