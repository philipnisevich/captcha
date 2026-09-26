import SwiftUI

struct ContentView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var verification = HingeVerificationModel()

  var body: some View {
    monitoredScreen
      .tint(.accentColor)
      .sensoryFeedback(.success, trigger: verification.isVerified)
  }

  @ViewBuilder
  private var monitoredScreen: some View {
    if #available(iOS 27.1, *) {
      screenContent
        .onHingeChange(isEnabled: !verification.isVerified) { _, context in
          guard let hinge = context.hinge else {
            verification.markSensorUnavailable(isSupportedOS: true)
            return
          }

          verification.updateHinge(
            angleDegrees: hinge.angle.degrees,
            isPartiallyOpen: hinge.status == .partiallyOpen
          )
        }
    } else {
      screenContent
        .onAppear {
          verification.markSensorUnavailable(isSupportedOS: false)
        }
    }
  }

  @ViewBuilder
  private var screenContent: some View {
    if horizontalSizeClass == .regular {
      if #available(iOS 27.1, *) {
        wideLayout
      } else {
        compactLayout
      }
    } else {
      compactLayout
    }
  }

  @available(iOS 27.1, *)
  private var wideLayout: some View {
    ArrangementView {
      instructionPanel
    } secondary: {
      measurementPanel
    }
    .arrangementViewStyle(.split)
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
  }

  private var compactLayout: some View {
    ScrollView {
      VStack(spacing: 0) {
        instructionPanel
        measurementPanel
      }
      .frame(maxWidth: 520)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
  }

  private var instructionPanel: some View {
    VStack(alignment: .leading, spacing: 28) {
      brandMark

      VStack(alignment: .leading, spacing: 12) {
        Text("HUMAN CHECK")
          .font(.caption.weight(.bold))
          .tracking(1.6)
          .foregroundStyle(.secondary)

        Text("Prove you’re\nhuman.")
          .font(.system(.largeTitle, design: .rounded).weight(.bold))
          .fixedSize(horizontal: false, vertical: true)

        Text("Follow three different angle targets. Hold each one steady for a second to complete the check.")
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Label("Your angle stays on this device", systemImage: "lock.shield")
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(26)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var brandMark: some View {
    HStack(spacing: 12) {
      Image(systemName: "angle")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 48, height: 48)
        .background(
          Color.accentColor,
          in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text("FOLD CHECK")
          .font(.caption.weight(.heavy))
          .tracking(1.4)

        Text("Device verification")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var measurementPanel: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("TARGET ANGLE")
            .font(.caption2.weight(.bold))
            .tracking(1.3)
            .foregroundStyle(.secondary)

          Text(verification.currentTargetText)
            .font(.system(.title, design: .rounded).weight(.bold))
        }

        Spacer(minLength: 12)

        Text(verification.isVerified ? "COMPLETE" : "ANGLE \(verification.currentStepNumber) OF \(verification.totalStepCount)")
          .font(.caption2.weight(.bold))
          .tracking(0.8)
          .foregroundStyle(verification.isVerified ? Color.green : Color.secondary)
          .padding(.horizontal, 11)
          .padding(.vertical, 8)
          .background(Color.primary.opacity(0.06), in: Capsule())
      }

      FoldAngleGauge(
        angleDegrees: verification.angleDegrees,
        targetDegrees: verification.currentTargetAngle
      )
      .frame(height: 196)

      challengeProgress

      Divider()

      statusSummary
      holdProgress

      if verification.isVerified {
        Button {
          verification.startNewChallenge()
        } label: {
          Label("New challenge", systemImage: "arrow.counterclockwise")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
              Color.accentColor,
              in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts a new three-angle captcha.")
      }
    }
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .fill(Color(uiColor: .secondarySystemGroupedBackground))
    )
    .overlay {
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    .frame(maxWidth: 460)
    .frame(maxWidth: .infinity)
    .padding(24)
  }

  private var statusSummary: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: verification.phase.symbolName)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(statusColor)
        .frame(width: 32, height: 32)
        .background(statusColor.opacity(0.12), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(verification.statusTitle)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)

        Text(verification.statusDescription)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var challengeProgress: some View {
    HStack(spacing: 7) {
      ForEach(0..<verification.totalStepCount, id: \.self) { step in
        Capsule()
          .fill(stepColor(for: step))
          .frame(maxWidth: .infinity)
          .frame(height: 6)
      }
    }
    .accessibilityElement()
    .accessibilityLabel("Captcha progress")
    .accessibilityValue("\(verification.completedStepCount) of \(verification.totalStepCount) angles complete")
  }

  private func stepColor(for step: Int) -> Color {
    if step < verification.completedStepCount {
      return .accentColor
    }
    if step == verification.currentStepIndex && !verification.isVerified {
      return Color.accentColor.opacity(0.35)
    }
    return Color.primary.opacity(0.08)
  }

  private var holdProgress: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.primary.opacity(0.08))

        Capsule()
          .fill(verification.isVerified ? Color.green : Color.accentColor)
          .frame(width: geometry.size.width * verification.holdProgress)
      }
    }
    .frame(height: 7)
    .accessibilityElement()
    .accessibilityLabel("Current angle hold progress")
    .accessibilityValue("\(Int(verification.holdProgress * 100)) percent")
  }

  private var statusColor: Color {
    switch verification.phase {
    case .verified:
      return .green
    case .noHinge, .requiresIOS27:
      return .orange
    default:
      return .accentColor
    }
  }
}
