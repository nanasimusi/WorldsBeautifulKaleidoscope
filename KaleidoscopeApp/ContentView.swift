import SwiftUI
import Metal
import MetalKit
import CoreMotion

struct ContentView: View {
    var body: some View {
        GeometryReader { geometry in
            KaleidoscopeView()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea()
        }
    }
}

struct KaleidoscopeView: UIViewRepresentable {
    class Coordinator {
        var renderer: KaleidoscopeRenderer?
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            renderer?.handleTapInteraction(at: location)
        }
        
        @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            let direction: SwipeDirection
            switch gesture.direction {
            case .up: direction = .up
            case .down: direction = .down
            case .left: direction = .left
            case .right: direction = .right
            default: direction = .up
            }
            renderer?.handleSwipeInteraction(direction: direction)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        
        // CRITICAL: Configure MTKView formats BEFORE initializing renderer
        // Optimize for smooth 60fps instead of power-hungry 120fps
        metalView.preferredFramesPerSecond = 60
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.depthStencilPixelFormat = .depth32Float
        
        // Enable performance optimizations
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false  // Use draw(in:) for continuous rendering
        
        print("MTKView configuration before renderer init:")
        print("  - Color format: \(metalView.colorPixelFormat)")
        print("  - Depth format: \(metalView.depthStencilPixelFormat)")
        
        let renderer = KaleidoscopeRenderer(metalView: metalView)
        context.coordinator.renderer = renderer
        metalView.delegate = renderer
        
        // Add gesture recognizers to MTKView
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        metalView.addGestureRecognizer(tapGesture)
        
        let swipeUpGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeUpGesture.direction = .up
        metalView.addGestureRecognizer(swipeUpGesture)
        
        let swipeDownGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeDownGesture.direction = .down
        metalView.addGestureRecognizer(swipeDownGesture)
        
        let swipeLeftGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeLeftGesture.direction = .left
        metalView.addGestureRecognizer(swipeLeftGesture)
        
        let swipeRightGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeRightGesture.direction = .right
        metalView.addGestureRecognizer(swipeRightGesture)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}


#Preview {
    ContentView()
}