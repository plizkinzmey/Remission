import Foundation
import Testing

@testable import Remission

@Suite("Session Repository Types Tests")
struct SessionRepositoryTypesTests {
    // Проверяет isEmpty для SessionUpdate.
    @Test
    func sessionUpdateIsEmptyOnlyWhenNoFieldsProvided() {
        let empty = SessionRepository.SessionUpdate()
        #expect(empty.isEmpty)

        let withSeedRatio = SessionRepository.SessionUpdate(
            seedRatioLimit: .init(isEnabled: true, value: 1.5)
        )
        #expect(withSeedRatio.isEmpty == false)
    }

    // Проверяет, что вложенные апдейты могут существовать независимо.
    @Test
    func speedLimitsAndQueueUpdatesCanBeSetIndependently() {
        let speedUpdate = SessionRepository.SpeedLimitsUpdate(
            download: .init(isEnabled: true, kilobytesPerSecond: 1000)
        )
        let queueUpdate = SessionRepository.QueueUpdate(
            stalledMinutes: 30
        )

        let update = SessionRepository.SessionUpdate(
            speedLimits: speedUpdate,
            queue: queueUpdate,
            seedRatioLimit: nil
        )

        #expect(update.isEmpty == false)
        #expect(update.speedLimits?.download?.kilobytesPerSecond == 1000)
        #expect(update.queue?.stalledMinutes == 30)
    }
}
