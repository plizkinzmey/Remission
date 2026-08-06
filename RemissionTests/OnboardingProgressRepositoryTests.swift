import Foundation
import Testing

@testable import Remission

@Suite("Onboarding Progress Repository Tests")
struct OnboardingProgressRepositoryTests {
    // Проверяет in-memory реализацию: значение меняется и читается корректно.
    @Test
    func inMemoryStoresCompletionFlag() async {
        let repository = OnboardingProgressRepository.inMemory()
        #expect(await repository.hasCompletedOnboarding() == false)

        await repository.setCompletedOnboarding(true)
        #expect(await repository.hasCompletedOnboarding())
    }

    // Проверяет UserDefaults-реализацию на изолированном suite.
    @Test
    func userDefaultsPersistsCompletionFlag() async {
        let suiteName = "OnboardingProgressRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = OnboardingProgressRepository.userDefaults(suiteName: suiteName)
        #expect(await repository.hasCompletedOnboarding() == false)

        await repository.setCompletedOnboarding(true)

        let reloaded = OnboardingProgressRepository.userDefaults(suiteName: suiteName)
        #expect(await reloaded.hasCompletedOnboarding())

        defaults.removePersistentDomain(forName: suiteName)
    }
}
