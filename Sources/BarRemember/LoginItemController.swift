import Combine
import ServiceManagement

enum LoginItemState: Equatable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable
}

@MainActor
final class LoginItemController: ObservableObject {
  @Published private(set) var state: LoginItemState = .disabled
  @Published var errorMessage: String?

  init() {
    refresh()
  }

  func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        if SMAppService.mainApp.status != .enabled {
          try SMAppService.mainApp.register()
        }
      } else {
        if SMAppService.mainApp.status != .notRegistered {
          try SMAppService.mainApp.unregister()
        }
      }
      refresh()
    } catch {
      refresh()
      errorMessage = "로그인 시 실행 설정을 변경하지 못했습니다: \(error.localizedDescription)"
    }
  }

  func refresh() {
    state = Self.mappedState(from: SMAppService.mainApp.status)
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }

  nonisolated static func mappedState(from status: SMAppService.Status) -> LoginItemState {
    switch status {
    case .notRegistered:
      .disabled
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }
}
