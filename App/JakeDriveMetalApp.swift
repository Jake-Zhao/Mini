import SwiftUI

@main
@MainActor
struct JakeDriveMetalApp: App {
    @StateObject private var model = LabModel()
    var body: some Scene { WindowGroup { CockpitView(model:model) } }
}
@MainActor
struct CockpitView: View {
    @ObservedObject var model: LabModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controls = false
    var body: some View {
        ZStack(alignment:.topLeading) {
            MetalHost(model:model,active:scenePhase == .active,systemReducedMotion:reduceMotion)
                .ignoresSafeArea()
                .accessibilityElement(children:.ignore)
                .accessibilityLabel("演示车速 \(model.spokenSpeed)，挡位 \(model.spokenGear)")
                .contentShape(Rectangle())
                .onTapGesture(count:2) { controls = true }
            Button { controls = true } label: {
                Text("DEMO").font(.system(size:10,weight:.medium,design:.monospaced))
                    .tracking(1.6).foregroundStyle(.white.opacity(0.55))
                    .frame(minWidth:60,minHeight:44)
            }
            .buttonStyle(.plain).padding(.leading,4).padding(.top,2)
            .accessibilityLabel("模拟数据，打开渲染控制")
            if let error = model.error {
                VStack(alignment:.leading,spacing:12) {
                    Text("渲染未通过").font(.headline)
                    Text(error).font(.system(size:13,design:.monospaced))
                    Text("不会用参考图片替代失败的 Metal 输出。请保留错误并检查工程。")
                    Button("查看控制与诊断") { controls = true }
                }.padding(24).background(.black.opacity(0.90)).foregroundStyle(.white)
                    .frame(maxWidth:560).frame(maxWidth:.infinity,maxHeight:.infinity)
            }
        }
        .statusBarHidden(true).persistentSystemOverlays(.hidden)
        .onAppear { model.setActive(scenePhase == .active) }
        .onChange(of:scenePhase) { _,phase in model.setActive(phase == .active) }
        .sheet(isPresented:$controls) { ControlsView(model:model) }
        .preferredColorScheme(.dark)
    }
}
@MainActor
struct ControlsView: View {
    @ObservedObject var model: LabModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("输入 · 只使用明确标记的模拟数据") {
                    HStack { ForEach([0,20,72,88,100,128],id:\.self) { v in Button("\(v)") { model.selectSpeed(Double(v)) }.buttonStyle(.bordered) } }
                    HStack { Text("车速"); Slider(value:$model.speed,in:0...255,step:1,onEditingChanged:{ _ in model.autoCycle=false;model.publish() }); Text("\(Int(model.speed))").monospacedDigit() }
                    Toggle("40 秒行驶序列",isOn:$model.autoCycle)
                    Button("从静止重新播放") { model.restartCycle() }
                    Picker("挡位",selection:$model.gear) { ForEach(["-","P","R","N","D","D1","D2","D3","D4","D5","D6","D7","D8"],id:\.self) { Text($0).tag($0) } }
                    Toggle("制动灯（演示开关）",isOn:$model.brake)
                    Toggle("车速失效 / 未知",isOn:$model.invalidSpeed)
                    Text("此工程未连接 Vgate，也不推断真实挡位或刹车。所有这些值均为 DEMO。").font(.footnote).foregroundStyle(.secondary)
                }
                Section("渲染") {
                    Toggle("冻结演示与环境位移",isOn:$model.paused)
                    Toggle("减少动态效果",isOn:$model.reduced)
                    Toggle("轻微远景景深（默认关）",isOn:$model.cinematicDepth)
                    Toggle("33 样本曝光参考（非实时性能目标）",isOn:$model.referenceExposure)
                    Toggle("二进制雨",isOn:$model.rain)
                    Toggle("车辆与接地层",isOn:$model.car)
                    Toggle("前景数字",isOn:$model.hud)
                    Picker("质量",selection:$model.qualityMode) { ForEach(["自动","高","均衡","节能"],id:\.self) { Text($0).tag($0) } }
                    Picker("调试输出",selection:$model.debugMode) { ForEach(["画面","深度","运动向量"],id:\.self) { Text($0).tag($0) } }
                    Text(model.report).font(.system(.footnote,design:.monospaced))
                }
                Section("证据") {
                    Button("保存下一帧实际 Metal 输出") { model.takeScreenshot() }
                    if let url=model.screenshot { ShareLink("分享实际渲染截图",item:url) }
                }
            }
            .navigationTitle("JAKE · Metal Lab")
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("回到驾驶舱") { model.publish();dismiss() } } }
        }
    }
}
