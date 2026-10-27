import Foundation
import Combine
import QuartzCore
import UIKit
import JakeCore

@MainActor
final class LabModel: ObservableObject {
    let mailbox = TelemetryMailbox()
    weak var renderer: JakeRenderer?
    @Published var speed = 72.0
    @Published var gear = "D3"
    @Published var brake = false
    @Published var autoCycle = false
    @Published var invalidSpeed = false
    @Published var paused = false
    @Published var cinematicDepth = false
    @Published var referenceExposure = false
    @Published var reduced = false
    @Published var rain = true
    @Published var car = true
    @Published var hud = true
    @Published var qualityMode = "自动"
    @Published var debugMode = "画面"
    @Published var error: String?
    @Published var report = "等待 GPU 首帧"
    @Published var screenshot: URL?
    @Published var spokenSpeed = "72"
    @Published var spokenGear = "D3"
    private var timer: Timer?
    private var active = true
    private var demoElapsed = 0.0
    private var lastTick: Double?
    private var epoch: UInt64 = 1
    init() { publish(); startTimer() }
    var options: RenderOptions {
        var o = RenderOptions(); o.paused = paused; o.reducedMotion = reduced
        o.cinematicDepth = cinematicDepth; o.referenceExposure = referenceExposure
        o.rainEnabled = rain; o.carEnabled = car; o.hudEnabled = hud
        o.automaticQuality = qualityMode == "自动"
        o.manualQuality = qualityMode == "节能" ? .cool : (qualityMode == "均衡" ? .balanced : .high)
        o.debugMode = debugMode == "深度" ? 1 : (debugMode == "运动向量" ? 2 : (debugMode == "粗糙度" ? 3 : (debugMode == "湿度" ? 4 : (debugMode == "对象ID" ? 5 : 0))))
        return o
    }
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.publish() }
        }
    }
    func setActive(_ value: Bool) {
        active = value; lastTick = nil
        UIApplication.shared.isIdleTimerDisabled = value
        if value { startTimer(); publish() } else { timer?.invalidate(); timer = nil }
    }
    func restartCycle() { demoElapsed = 0; lastTick = nil; epoch &+= 1; autoCycle = true; renderer?.resetMotion(); publish() }
    func selectSpeed(_ value: Double) { autoCycle = false; invalidSpeed = false; speed = value; publish() }
    func publish() {
        guard active else { return }
        let now = CACurrentMediaTime()
        if autoCycle && !paused, let previous = lastTick { demoElapsed += min(0.25,max(0,now-previous)) }
        lastTick = now
        var t: Telemetry
        if autoCycle {
            t = DemoCycle.sample(time:demoElapsed,epoch:epoch)
            t.speed?.time = now; t.gear?.time = now; t.brake?.time = now
        } else {
            let g: Gear
            switch gear {
            case "P": g = .park
            case "R": g = .reverse
            case "N": g = .neutral
            case "D": g = .drive
            case "-": g = .unknown
            default: g = .forward(Int(gear.dropFirst()) ?? 0)
            }
            t = Telemetry(epoch:epoch,origin:.demo,
                speed: Reading(speed,time:now,epoch:epoch,origin:.demo),
                gear: Reading(g,time:now,epoch:epoch,origin:.demo),
                brake: Reading(brake ? .pressed:.released,time:now,epoch:epoch,origin:.demo))
        }
        if invalidSpeed { t.speed = nil }
        mailbox.publish(t)
        let resolved = t.resolve(at:now);spokenSpeed = resolved.speedText;spokenGear = resolved.gearText
    }
    func takeScreenshot() {
        guard let renderer else { error = "渲染器尚未就绪。"; return }
        renderer.requestScreenshot { [weak self] result in
            switch result { case .success(let url): self?.screenshot = url; case .failure(let e): self?.error = e.localizedDescription }
        }
    }
    func receive(_ r: GPUReport) {
        let gpu = r.gpuMilliseconds.map { String(format:"%.2f ms",$0) } ?? "GPU 时间不可用"
        report = "GPU \(gpu) · 目标 \(r.quality.fps) FPS · 背景 \(Int(r.quality.scale*100))% · 已提交 \(r.framesSubmitted) 帧"
    }
}
