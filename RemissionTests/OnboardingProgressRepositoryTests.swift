import Foundation
import Testing

@testable import Remission

@Suite("Onboarding Progress Repository Tests")
struct OnboardingProgressRepositoryTests {
    // Проверяет in-memory реализацию: значение меняется и читается корректно.
    @Test
    func inMemoryStoresCompletionFlag() {
        let repository = OnboardingProgressRepository.inMemory()
        #expect(repository.hasCompletedOnboarding() == false)

        repository.setCompletedOnboarding(true)
        #expect(repository.hasCompletedOnboarding())
    }

    // Проверяет UserDefaults-реализацию на изолированном suite.
    @Test
    func userDefaultsPersistsCompletionFlag() {
        let suiteName = "OnboardingProgressRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = OnboardingProgressRepository.userDefaults(defaults: defaults)
        #expect(repository.hasCompletedOnboarding() == false)

        repository.setCompletedOnboarding(true)

        let reloaded = OnboardingProgressRepository.userDefaults(defaults: defaults)
        #expect(reloaded.hasCompletedOnboarding())

        defaults.removePersistentDomain(forName: suiteName)
    }
}
