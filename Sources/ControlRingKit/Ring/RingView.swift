import SwiftUI

public struct RingView: View {
    @ObservedObject var viewModel: RingViewModel
    @Environment(\.colorScheme) private var scheme
    @State private var isDragging = false
    let onActivate: () -> Void
    let onMoveDrag: () -> Void
    let onMoveEnd: () -> Void

    public init(viewModel: RingViewModel,
                onActivate: @escaping () -> Void,
                onMoveDrag: @escaping () -> Void = {},
                onMoveEnd: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onActivate = onActivate
        self.onMoveDrag = onMoveDrag
        self.onMoveEnd = onMoveEnd
    }

    /// The ring is drawn centered inside a fixed transparent square so it can be
    /// resized without resizing the underlying window.
    public static let panelSize: CGFloat = RingMetrics.panelSize
    private static let space = "ring"
    private var center: CGPoint { CGPoint(x: Self.panelSize / 2, y: Self.panelSize / 2) }
    private var panelBox: CGSize { CGSize(width: Self.panelSize, height: Self.panelSize) }
    private static let dragThreshold: CGFloat = 6

    public var body: some View {
        let accent = Theme.accent(for: viewModel.currentMode)
        let m = RingMetrics(diameter: viewModel.diameter)

        ZStack {
            // Visual layers (non-interactive — all input goes through the overlay below).
            Circle()
                .fill(Theme.ringPlate(scheme))
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: m.bezelRadius * 2, height: m.bezelRadius * 2)
                .position(center)

            RingBezelCanvas(bezelRadius: m.bezelRadius,
                            innerGlowRadius: m.innerGlowRadius, accent: accent)
                .frame(width: Self.panelSize, height: Self.panelSize)

            OuterRingView(viewModel: viewModel, center: center,
                          radius: m.outerRadius, slotSize: m.slotSize,
                          accent: accent, onActivate: onActivate)
            ModeRingView(viewModel: viewModel, center: center,
                         radius: m.innerRadius, chipSize: m.chipSize,
                         accent: accent, onActivate: onActivate)
            CenterHubView(viewModel: viewModel, radius: m.centerHubRadius,
                          accent: accent, onActivate: onActivate)
                .position(center)

            // Single input layer: hover = angle-select, tap = activate, drag = move window.
            inputOverlay(radius: m.bezelRadius)

            // Resize handles sit above the input layer so they win drags at the corners.
            ResizeHandlesView(center: center, radius: m.handleRadius,
                              handleSize: m.chipSize * 0.5, accent: accent) { location in
                let dist = hypot(location.x - center.x, location.y - center.y)
                viewModel.setDiameter(dist * (560.0 / 268.0)) // invert bezel ratio
            }

            if let msg = viewModel.transientMessage {
                Text(msg)
                    .font(.callout).foregroundStyle(.white).lineLimit(2)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.85)))
                    .frame(maxWidth: m.diameter * 0.7)
                    .position(x: center.x, y: center.y + m.bezelRadius + 26)
                    .transition(.opacity)
            }
        }
        .frame(width: Self.panelSize, height: Self.panelSize)
        .coordinateSpace(name: Self.space)
        .animation(.easeInOut(duration: 0.2), value: viewModel.transientMessage)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: viewModel.diameter)
        .scaleEffect(viewModel.isOpen ? 1 : 0.86)
        .opacity(viewModel.isOpen ? 1 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: viewModel.isOpen)
    }

    private func inputOverlay(radius: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(0.001)) // effectively transparent but hit-testable
            .frame(width: radius * 2, height: radius * 2)
            .contentShape(Circle())
            .position(center)
            .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
                if case .active(let loc) = phase, !isDragging {
                    viewModel.applyCursor(loc, in: panelBox)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let moved = hypot(value.translation.width, value.translation.height)
                        if isDragging || moved > Self.dragThreshold {
                            isDragging = true
                            onMoveDrag()
                        } else {
                            viewModel.applyCursor(value.location, in: panelBox)
                        }
                    }
                    .onEnded { value in
                        if isDragging {
                            onMoveEnd()
                        } else {
                            viewModel.applyCursor(value.location, in: panelBox)
                            onActivate()
                        }
                        isDragging = false
                    }
            )
    }
}

/// Four diagonal grab handles on the bezel; dragging any of them scales the ring.
struct ResizeHandlesView: View {
    let center: CGPoint
    let radius: CGFloat
    let handleSize: CGFloat
    let accent: Color
    /// Called with the drag location (in the ring coordinate space) while resizing.
    let onResize: (CGPoint) -> Void

    private let angles: [CGFloat] = [45, 135, 225, 315]

    var body: some View {
        ForEach(angles, id: \.self) { deg in
            let a = deg * .pi / 180
            let pos = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            handle
                .position(pos)
                .gesture(
                    DragGesture(coordinateSpace: .named("ring"))
                        .onChanged { onResize($0.location) }
                )
        }
    }

    private var handle: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().stroke(accent.opacity(0.7), lineWidth: 1.5)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: handleSize * 0.5, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(width: handleSize, height: handleSize)
        .contentShape(Circle())
        .help("Drag to resize the ring")
    }
}
