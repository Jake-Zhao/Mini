import SwiftUI
import MetalKit

@MainActor
struct MetalHost: UIViewRepresentable {
    @ObservedObject var model: LabModel
    var active: Bool
    var systemReducedMotion: Bool
    final class Coordinator { var renderer: JakeRenderer? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame:.zero,device:MTLCreateSystemDefaultDevice())
        view.backgroundColor = .black; view.isOpaque = true
        do {
            let renderer = try JakeRenderer(view:view,mailbox:model.mailbox)
            renderer.onError = { [weak model] message in model?.error = message }
            renderer.onReport = { [weak model] report in model?.receive(report) }
            context.coordinator.renderer = renderer; model.renderer = renderer
        } catch { DispatchQueue.main.async { model.error = error.localizedDescription } }
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        var options = model.options; options.reducedMotion = options.reducedMotion || systemReducedMotion
        renderer.options = options
        if view.isPaused == active { renderer.setActive(active,view:view) }
    }
    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        uiView.isPaused = true; uiView.delegate = nil; coordinator.renderer = nil
    }
}
