-- Archive capacity is fixed; replacement and world-copy policy are decided by callers.
return {
	SchemaVersion = 1,
	ArchiveStore = "EcoshiftWorldArchives_v1",
	ManifestStore = "EcoshiftWorldManifests_v1",
	MaxSlots = 5,
	MaxRosterSize = 6,
	MaxNameCharacters = 32,
	MaxNameBytes = 128,
	DefaultName = "Untitled expedition",
	DataStoreAttempts = 3,
}
