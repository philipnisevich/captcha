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

  private static let targetCount = 3
  private static let targetRange = 105...170
  private static let minimumTargetSeparation = 10
  private static let targetTolerance = 4.0

  private let holdDuration = 1.0

  private(set) var targetAngles: [Double]
  private(set) var currentStepIndex = 0
  private(set) var phase: Phase = .waiting
  private(set) var angleDegrees: Double?
  private(set) var holdProgress = 0.0

  @ObservationIgnored private var holdTask: Task<Void, Never>?
  @ObservationIgnored private var holdStartedAt: Date?

  init() {
    targetAngles = Self.makeTargetSequence()
  }

  var isVerified: Bool {
    phase == .verified
  }

  var currentTargetAngle: Double {
    targetAngles[min(currentStepIndex, targetAngles.count - 1)]
  }

  var currentTargetText: String {
    "\(Int(currentTargetAngle.rounded()))°"
  }

  var currentStepNumber: Int {
    min(currentStepIndex + 1, totalStepCount)
  }

  var totalStepCount: Int {
    targetAngles.count
  }

  var completedStepCount: Int {
    isVerified ? totalStepCount : currentStepIndex
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
      return "Captcha complete"
    case .noHinge:
      return "Hinge sensor unavailable"
    case .requiresIOS27:
      return "iOS 27.1 required"
    }
  }

  var statusDescription: String {
    switch phase {
    case .waiting:
      return "Move toward \(currentTargetText) to begin. Complete all three angles."
    case .openMore:
      return "Current angle: \(currentAngleText). Open slightly to reach \(currentTargetText)."
    case .closeSlightly:
      return "Current angle: \(currentAngleText). Close slightly to reach \(currentTargetText)."
    case .holding:
      return "Stay within \(Int(Self.targetTolerance))° of \(currentTargetText) for one second."
    case .verified:
      return "All three angle holds are complete."
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
      phase = clampedAngle < currentTargetAngle ? .openMore : .closeSlightly
      return
    }

    guard abs(clampedAngle - currentTargetAngle) <= Self.targetTolerance else {
      stopHolding()
      phase = clampedAngle < currentTargetAngle ? .openMore : .closeSlightly
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

  func startNewChallenge() {
    stopHolding()
    targetAngles = Self.makeTargetSequence(avoiding: targetAngles)
    currentStepIndex = 0
    angleDegrees = nil
    phase = .waiting
  }

  private static func makeTargetSequence(avoiding previousSequence: [Double]? = nil) -> [Double] {
    while true {
      var sequence: [Double] = []

      while sequence.count < targetCount {
        let candidate = Double(Int.random(in: targetRange))
        guard sequence.allSatisfy({
          abs($0 - candidate) >= Double(minimumTargetSeparation)
        }) else { continue }
        sequence.append(candidate)
      }

      guard sequence != previousSequence else { continue }
      return sequence
    }
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
        self.finishCurrentStep()
        return
      }
    }
  }

  private func finishCurrentStep() {
    holdStartedAt = nil
    holdTask = nil

    guard currentStepIndex + 1 < totalStepCount else {
      holdProgress = 1
      phase = .verified
      return
    }

    currentStepIndex += 1
    holdProgress = 0
    let currentAngle = angleDegrees ?? currentTargetAngle
    phase = currentAngle < currentTargetAngle ? .openMore : .closeSlightly
  }

  private func stopHolding() {
    holdTask?.cancel()
    holdTask = nil
    holdStartedAt = nil
    holdProgress = 0
  }
}
