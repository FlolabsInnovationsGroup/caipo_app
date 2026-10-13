import Foundation

final class SecureStoreHostApiImpl: SecureStoreHostApi {
    func write(key: String, value: String) async throws {
        try CaipoKeychain.write(key: key, value: value)
    }

    func read(key: String) async throws -> String? {
        try CaipoKeychain.read(key: key)
    }

    func delete(key: String) async throws {
        CaipoKeychain.delete(key: key)
    }

    func deleteAll() async throws {
        CaipoKeychain.deleteAll()
    }
}
