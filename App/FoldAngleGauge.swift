import SwiftUI

struct FoldAngleGauge: View {
  var angleDegrees: Double?
  var targetDegrees: Double

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size

      ZStack {
        Canvas { context, canvasSize in
          let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height - 18)
          let radius = min(canvasSize.width / 2 - 20, canvasSize.height - 48)

          context.stroke(
            arcPath(to: 180, center: center, radius: radius),
            with: .color(Color.primary.opacity(0.12)),
            style: StrokeStyle(lineWidth: 11, lineCap: .round)
          )

          if let angleDegrees {
            context.stroke(
              arcPath(to: min(max(angleDegrees, 0), 180), center: center, radius: radius),
              with: .color(Color.accentColor.opacity(0.4)),
              style: StrokeStyle(lineWidth: 11, lineCap: .round)
            )
          }

          for tickDegrees in stride(from: 0.0, through: 180.0, by: 30.0) {
            let isTarget = abs(tickDegrees - targetDegrees) < 0.1
            let outer = point(for: tickDegrees, center: center, radius: radius)
            let inner = point(
              for: tickDegrees,
              center: center,
              radius: radius - (isTarget ? 19 : 10)
            )
            var tick = Path()
            tick.move(to: inner)
            tick.addLine(to: outer)
            context.stroke(
              tick,
              with: .color(isTarget ? Color.accentColor : Color.secondary.opacity(0.55)),
              lineWidth: isTarget ? 2.5 : 1.5
            )
          }

          if let angleDegrees {
            let marker = point(
              for: min(max(angleDegrees, 0), 180),
              center: center,
              radius: radius
            )
            let markerRect = CGRect(x: marker.x - 7, y: marker.y - 7, width: 14, height: 14)
            context.fill(
              Path(ellipseIn: markerRect.insetBy(dx: -2.5, dy: -2.5)),
              with: .color(Color(uiColor: .secondarySystemGroupedBackground))
            )
            context.fill(Path(ellipseIn: markerRect), with: .color(Color.accentColor))
          }
        }

        VStack(spacing: 2) {
          Text(currentAngleText)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .contentTransition(.numericText())

          Text("LIVE ANGLE")
            .font(.caption2.weight(.semibold))
            .tracking(1.3)
            .foregroundStyle(.secondary)
        }
        .position(x: size.width / 2, y: size.height - 47)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Live hinge angle")
    .accessibilityValue(accessibilityValue)
  }

  private var currentAngleText: String {
    guard let angleDegrees else { return "—°" }
    return "\(Int(angleDegrees.rounded()))°"
  }

  private var accessibilityValue: String {
    guard let angleDegrees else { return "Waiting for hinge movement. Target 90 degrees." }
    return "\(Int(angleDegrees.rounded())) degrees. Target \(Int(targetDegrees)) degrees."
  }

  private func arcPath(to endDegrees: Double, center: CGPoint, radius: CGFloat) -> Path {
    var path = Path()

    for degrees in stride(from: 0.0, through: endDegrees, by: 2.0) {
      let location = point(for: degrees, center: center, radius: radius)
      if degrees == 0 {
        path.move(to: location)
      } else {
        path.addLine(to: location)
      }
    }

    path.addLine(to: point(for: endDegrees, center: center, radius: radius))
    return path
  }

  private func point(for degrees: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
    let radians = Double.pi - (degrees / 180 * Double.pi)
    return CGPoint(
      x: center.x + CGFloat(cos(radians)) * radius,
      y: center.y - CGFloat(sin(radians)) * radius
    )
  }
}
