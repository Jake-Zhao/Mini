# 04 · 素材编译与字形合同

## 4.1 可重复输入
`tools/build_assets.py`只读取当前仓库Source与Config。使用固定随机种子，不请求网络、不调用OCR、不依赖未知字体、不从批准图裁一个72来冒充动态数字。

```pseudo
load rear_original.png
registration = read registration.json
silhouette = rasterize(registration.outline, supersample=4)
subtract only explicitly registered holes
paint = rasterize(registered body panels)
brake = rasterize(registered lamp cores)

sourceLinear = decode_sRGB(source)
recolor only paint region
place supplied plate.png through registered quadrilateral
retain solid dark body pixels wherever silhouette says covered
prepare body-without-emission, brake core, soft halo, contact matte
export editable PNGs
compile each sprite: linearize → premultiply → float16 runtime data
```

车辆源图信息上限保持不变；重采样不会创造原图不存在的细节。实拍照片中的镜面高光仍然烘焙存在，因此车体只做温和环境融合，不给予虚假的完整物理重打光能力。

## 4.2 车身、刹车与接地
透明轮廓只定义覆盖；不能同时充当阴影、雾或发光mask。灯罩红色并不等于刹车正在点亮；没有可信刹车输入时只画非发光车身。刹车输入仅控制独立emission与halo，停车踩刹车仍允许亮。

接地点固定在车辆局部UV附近。阴影先乘背景，然后车体采用over合成；不能乘到车体alpha把轮胎/前杠抹掉。

## 4.3 字形不是字体猜谜
母版：`Source/Typography/glyph_0.svg`至9，以及D,N,P,R,dash。母版包含固定轮廓和笔锋纹理；不是一款可安装字体，也没有交付任何字体二进制。

```pseudo
for every supplied glyph:
    rasterize exact SVG
    crop to actual non-zero-alpha bounds
    normalize common cap-height without stretching aspect ratio
    place in atlas with gutters
    record UV, visible width, advance, capHeight
    convert whole atlas to linear-premultiplied runtime data
```

所有读数同一条管线，不允许72特殊化。

挡位框若与右下车辆投影重叠，向左避让；不能移动车速中心。车图必须是次要背景主体，挡位必须可读。

## 4.4 二进制源
“一路平安”按UTF-8编码，共12字节/96位，字节内高位在前：

```text
一 E4 B8 80
路 E8 B7 AF
平 E5 B9 B3
安 E5 AE 89
```

运行只画0/1，不出现中文、随机日文或意义不明的乱码。多个深度层由独立列种子、亮度、密度和下缘mask组成。所有符号都来自上述96位循环；垂直位移只随行驶距离，零速不滚动。

## 4.5 资产再生成
```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/build_assets.py
python3 tools/verify.py
```

资源构建失败时停止，不回退到任意网上图片或系统字体。
