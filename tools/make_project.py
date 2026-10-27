#!/usr/bin/env python3
"""Deterministic Xcode project writer; no XcodeGen/CocoaPods/network dependency."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1];out=R/'JakeDriveMetal.xcodeproj';(out/'xcshareddata/xcschemes').mkdir(parents=True,exist_ok=True)
objects={};counter=0
def obj(text):
 global counter
 counter+=1;ident=f'{counter:024X}';objects[ident]=text;return ident
def q(s):return json.dumps(str(s))
def file(path,typ):return obj('{isa=PBXFileReference;lastKnownFileType='+typ+';path='+q(path)+';sourceTree="<group>";}')
sources=[];refs=[]
for p in sorted(list((R/'App').glob('*.swift'))+list((R/'Renderer').glob('*.swift'))+list((R/'Renderer/Shaders').glob('*.metal'))):
 f=file(p.relative_to(R),'sourcecode.metal'if p.suffix=='.metal'else'sourcecode.swift');refs.append(f);sources.append(obj('{isa=PBXBuildFile;fileRef='+f+';}'))
for p in ['Renderer/Shaders/ShaderTypes.h','Renderer/Shaders/SceneCore.inc','App/Info.plist']:
 refs.append(file(p,'text.plist.xml'if p.endswith('.plist')else'sourcecode.c.h'))
# A root-level Resources/ makes CFBundle treat this flat iOS app as a
# legacy bundle, hiding its root Info.plist from codesign and simctl install.
resource_builds=[]
for directory in ['Resources/Art','Resources/Config']:
 resource=file(directory,'folder');refs.append(resource)
 resource_builds.append(obj('{isa=PBXBuildFile;fileRef='+resource+';}'))
asset=file('App/Assets.xcassets','folder.assetcatalog');refs.append(asset);ab=obj('{isa=PBXBuildFile;fileRef='+asset+';}')
product=obj('{isa=PBXFileReference;explicitFileType=wrapper.application;includeInIndex=0;path=JakeDriveMetal.app;sourceTree=BUILT_PRODUCTS_DIR;}')
products=obj('{isa=PBXGroup;children=('+product+',);name=Products;sourceTree="<group>";}')
main=obj('{isa=PBXGroup;children=('+','.join(refs+[products])+',);sourceTree="<group>";}')
package=obj('{isa=XCLocalSwiftPackageReference;relativePath=Core;}')
pkgdep=obj('{isa=XCSwiftPackageProductDependency;package='+package+';productName=JakeCore;}')
pkgb=obj('{isa=PBXBuildFile;productRef='+pkgdep+';}')
sp=obj('{isa=PBXSourcesBuildPhase;buildActionMask=2147483647;files=('+','.join(sources)+',);runOnlyForDeploymentPostprocessing=0;}')
rp=obj('{isa=PBXResourcesBuildPhase;buildActionMask=2147483647;files=('+','.join(resource_builds+[ab])+',);runOnlyForDeploymentPostprocessing=0;}')
fp=obj('{isa=PBXFrameworksBuildPhase;buildActionMask=2147483647;files=('+pkgb+',);runOnlyForDeploymentPostprocessing=0;}')
base='CLANG_ENABLE_MODULES=YES;CLANG_ENABLE_OBJC_ARC=YES;IPHONEOS_DEPLOYMENT_TARGET=17.0;SDKROOT=iphoneos;SWIFT_VERSION=5.0;ENABLE_USER_SCRIPT_SANDBOXING=YES;'
pd=obj('{isa=XCBuildConfiguration;name=Debug;buildSettings={'+base+'DEBUG_INFORMATION_FORMAT=dwarf;GCC_OPTIMIZATION_LEVEL=0;MTL_ENABLE_DEBUG_INFO=INCLUDE_SOURCE;SWIFT_OPTIMIZATION_LEVEL="-Onone";};}')
pr=obj('{isa=XCBuildConfiguration;name=Release;buildSettings={'+base+'DEBUG_INFORMATION_FORMAT="dwarf-with-dsym";SWIFT_OPTIMIZATION_LEVEL="-O";SWIFT_COMPILATION_MODE=wholemodule;};}')
pc=obj('{isa=XCConfigurationList;buildConfigurations=('+pd+','+pr+',);defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
targetsettings='CODE_SIGN_STYLE=Automatic;DEVELOPMENT_TEAM="";PRODUCT_BUNDLE_IDENTIFIER=com.jake.drivemetal;PRODUCT_NAME="$(TARGET_NAME)";INFOPLIST_FILE=App/Info.plist;GENERATE_INFOPLIST_FILE=NO;TARGETED_DEVICE_FAMILY=1;SUPPORTED_PLATFORMS="iphoneos iphonesimulator";SUPPORTS_MACCATALYST=NO;SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO;SWIFT_STRICT_CONCURRENCY=minimal;HEADER_SEARCH_PATHS="$(SRCROOT)/Renderer/Shaders";ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon;LD_RUNPATH_SEARCH_PATHS="$(inherited) @executable_path/Frameworks";'
td=obj('{isa=XCBuildConfiguration;name=Debug;buildSettings={'+targetsettings+'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG;};}')
tr=obj('{isa=XCBuildConfiguration;name=Release;buildSettings={'+targetsettings+'};}')
tc=obj('{isa=XCConfigurationList;buildConfigurations=('+td+','+tr+',);defaultConfigurationIsVisible=0;defaultConfigurationName=Release;}')
target=obj('{isa=PBXNativeTarget;buildConfigurationList='+tc+';buildPhases=('+sp+','+fp+','+rp+',);buildRules=();dependencies=();name=JakeDriveMetal;packageProductDependencies=('+pkgdep+',);productName=JakeDriveMetal;productReference='+product+';productType="com.apple.product-type.application";}')
project=obj('{isa=PBXProject;attributes={BuildIndependentTargetsInParallel=1;LastSwiftUpdateCheck=1600;LastUpgradeCheck=1600;TargetAttributes={'+target+'={CreatedOnToolsVersion=16.0;};};};buildConfigurationList='+pc+';compatibilityVersion="Xcode 14.0";developmentRegion=en;hasScannedForEncodings=0;knownRegions=(en,Base,zh-Hans);mainGroup='+main+';packageReferences=('+package+',);productRefGroup='+products+';projectDirPath="";projectRoot="";targets=('+target+',);}')
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1;classes={};objectVersion=56;objects={\n'+'\n'.join(k+'='+v+';'for k,v in objects.items())+'\n};rootObject='+project+';}\n')
buildable=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="JakeDriveMetal.app" BlueprintName="JakeDriveMetal" ReferencedContainer="container:JakeDriveMetal.xcodeproj"/>'
(out/'xcshareddata/xcschemes/JakeDriveMetal.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{buildable}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Wrote Xcode project:',len(sources),'compile units')
