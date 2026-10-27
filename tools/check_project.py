#!/usr/bin/env python3
"""Validate source layout, shader contracts, plist and Xcode project references."""
import json, plistlib, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def check():
    project=(ROOT/'JakeDriveMetal.xcodeproj/project.pbxproj').read_text()
    required=['Core/Package.swift','App/JakeDriveMetalApp.swift','App/MetalHost.swift','App/LabModel.swift',
      'Renderer/JakeRenderer.swift','Renderer/RenderTypes.swift','Renderer/Shaders/JakeShaders.metal',
      'Renderer/Shaders/SceneCore.inc','Renderer/Shaders/ShaderTypes.h','Resources/Config/assets.json',
      'Resources/Config/glyphs.json','Resources/Config/scene.json']
    for rel in required:assert (ROOT/rel).is_file(),f'Missing source: {rel}'
    for rel in ['App/JakeDriveMetalApp.swift','App/LabModel.swift','App/MetalHost.swift','Renderer/JakeRenderer.swift','Renderer/Shaders/JakeShaders.metal']:
        assert rel in project,f'Project omits {rel}'
    assert 'Resources' in project and 'Core' in project and 'AppIcon' in project
    assert 'path="Resources";' not in project, 'Root Resources/ hides the iOS Info.plist from CFBundle'
    for folder in ['Resources/Art','Resources/Config']:
        assert f'path="{folder}";' in project, f'Project omits resource folder {folder}'
    config=plistlib.loads((ROOT/'App/Info.plist').read_bytes())
    assert config['LSRequiresIPhoneOS'] and config['UIRequiresFullScreen']
    orientations=set(config['UISupportedInterfaceOrientations'])
    assert orientations=={'UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'}
    shader=(ROOT/'Renderer/Shaders/JakeShaders.metal').read_text()
    match=re.search(r'constant uint messageBits\[96\]\s*=\s*\{([^}]+)\}',shader)
    assert match,'Missing fixed 96-bit message'
    actual=[int(s) for s in match.group(1).split(',')]
    phrase='一路平安'.encode('utf-8')
    expected=[(byte>>bit)&1 for byte in phrase for bit in range(7,-1,-1)]
    assert actual==expected,'Shader code rain is not UTF-8 for 一路平安'
    expectedFunctions=['sceneFragment','motionBlurFragment','environmentFragment','bloomExtractFragment','bloomHorizontalFragment','bloomVerticalFragment','outputFragment','glyphFragment','advanceSpray']
    for fn in expectedFunctions:assert fn in shader,fn
    assets=json.loads((ROOT/'Resources/Config/assets.json').read_text())
    assert len(assets)==13
    byName={a['name']:a for a in assets}
    assert byName['car_body']['size']==[1400,521]
    scene=json.loads((ROOT/'Config/scene.json').read_text())
    assert 0.0<scene['optics']['exposureSeconds']<=.02
    assert len(scene['hud']['heroCenter'])==2
    print('SOURCE + SHADER CONTRACTS PASS:',len(required),'files',len(expectedFunctions),'shader stages',len(assets),'textures')
if __name__=='__main__':check()
