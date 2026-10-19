import Foundation
import SwiftData
import Observation
import KaloCalcCore

/// Everything the screens share: the database, the repository and the stores for the profile and settings.
@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let repository: Repository
    let profileStore: ProfileStore
    let settingsStore: SettingsStore
    let photos: PhotoStore

    init(container: ModelContainer, values: KeyValueStore, secrets: SecretStore, photos: PhotoStore = .shared) {
        self.container = container
        self.photos = photos
        repository = Repository(context: container.mainContext, counters: values)
        profileStore = ProfileStore(values)
        settingsStore = SettingsStore(values, secrets: secrets)
    }

    /// The real app: the store on disk, UserDefaults and the Keychain.
    static func live() -> AppModel {
        do {
            return AppModel(container: try Persistence.makeContainer(), values: UserDefaultsStore(), secrets: KeychainSecretStore())
        } catch {
            fatalError("Could not open the database: \(error)")
        }
    }

    /// Empty and throwaway, for tests and previews.
    static func inMemory() -> AppModel {
        let memory = MemoryKeyValueStore()
        return AppModel(container: try! Persistence.makeContainer(inMemory: true), values: memory, secrets: memory, photos: .temporary())
    }
}
