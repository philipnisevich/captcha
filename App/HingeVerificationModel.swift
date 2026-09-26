import Foundation
import Observation

@MainActor
@Observable
final class HingeVerificationModel {
  enum Phase: Equatable {
    case waiting
    case openMore
    case closeSlightly
    case holding
    case verified
    case noHinge
    case requiresIOS27

    var symbolName: String {
      switch self {
      case .waiting:
        return "move.3d"
      case .openMore:
        return "arrow.up"
      case .closeSlightly:
        return "arrow.down"
      case .holding:
        return "timer"
      case .verified:
        return "checkmark.seal.fill"
      case .noHinge, .requiresIOS27:
        return "info.circle"
      }
    }
  }

  static let targetAngle = 90.0

  private let targetTolerance = 7.0
  private let holdDuration = 1.0

  private(set) var phase: Phase = .waiting
  private(set) var angleDegrees: Double?
  private(set) var holdProgress = 0.0

  @ObservationIgnored private var holdTask: Task<Void, Never>?
  @ObservationIgnored private var holdStartedAt: Date?

  var isVerified: Bool {
    phase == .verified
  }

  var currentAngleText: String {
    guard let angleDegrees else { return "—°" }
    return "\(Int(angleDegrees.rounded()))°"
  }

  var statusTitle: String {
    switch phase {
    case .waiting:
      return "Move the hinge to start"
    case .openMore:
      return "Open the hinge a little more"
    case .closeSlightly:
      return "Close the hinge a little"
    case .holding:
      return "Hold it steady"
    case .verified:
      return "Human check passed"
    case .noHinge:
      return "Hinge sensor unavailable"
    case .requiresIOS27:
      return "iOS 27.1 required"
    }
  }

  var statusDescription: String {
    switch phase {
    case .waiting:
      return "Fold to 90° to begin the live check."
    case .openMore:
      return "Current angle: \(currentAngleText). Open slightly to reach 90°."
    case .closeSlightly:
      return "Current angle: \(currentAngleText). Close slightly to reach 90°."
    case .holding:
      return "Stay between 83° and 97° for one second."
    case .verified:
      return "The hinge held at 90° for one second."
    case .noHinge:
      return "Open this challenge on iPhone Duo to use its hinge sensor."
    case .requiresIOS27:
      return "Live hinge sensing requires iOS 27.1 or later."
    }
  }

  func updateHinge(angleDegrees: Double, isPartiallyOpen: Bool) {
    let clampedAngle = min(max(angleDegrees, 0), 180)
    self.angleDegrees = clampedAngle

    guard !isVerified else { return }

    guard isPartiallyOpen else {
      stopHolding()
      phase = clampedAngle < Self.targetAngle ? .openMore : .closeSlightly
      return
    }

    guard abs(clampedAngle - Self.targetAngle) <= targetTolerance else {
      stopHolding()
      phase = clampedAngle < Self.targetAngle ? .openMore : .closeSlightly
      return
    }

    beginHolding()
  }

  func markSensorUnavailable(isSupportedOS: Bool) {
    guard !isVerified else { return }
    stopHolding()
    angleDegrees = nil
    phase = isSupportedOS ? .noHinge : .requiresIOS27
  }

  func reset() {
    stopHolding()
    angleDegrees = nil
    phase = .waiting
  }

  private func beginHolding() {
    guard holdTask == nil else { return }

    phase = .holding
    holdStartedAt = Date()
    holdTask = Task { @MainActor [weak self] in
      guard let self else { return }

      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: 30_000_000)
        } catch {
          return
        }

        guard !Task.isCancelled, let startedAt = self.holdStartedAt else { return }
        self.holdProgress = min(Date().timeIntervalSince(startedAt) / self.holdDuration, 1)

        guard self.holdProgress >= 1 else { continue }
        self.phase = .verified
        self.holdTask = nil
        return
      }
    }
  }

  private func stopHolding() {
    holdTask?.cancel()
    holdTask = nil
    holdStartedAt = nil
    holdProgress = 0
  }
}
