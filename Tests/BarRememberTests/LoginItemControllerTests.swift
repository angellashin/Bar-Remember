import ServiceManagement
import Testing

@testable import BarRemember

struct LoginItemControllerTests {
  @Test func mapsLoginItemStatusesForTheUI() {
    #expect(LoginItemController.mappedState(from: .notRegistered) == .disabled)
    #expect(LoginItemController.mappedState(from: .enabled) == .enabled)
    #expect(LoginItemController.mappedState(from: .requiresApproval) == .requiresApproval)
    #expect(LoginItemController.mappedState(from: .notFound) == .unavailable)
  }
}
