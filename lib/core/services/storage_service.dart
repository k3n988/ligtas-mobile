/// Thin abstraction over local persistence.
/// MVP uses in-memory state managed by Riverpod providers.
/// Replace with Drift or Hive calls as the project matures.
abstract class StorageService {
  Future<void> init();
  Future<void> clear();
}

class InMemoryStorageService implements StorageService {
  @override
  Future<void> init() async {}

  @override
  Future<void> clear() async {}
}
