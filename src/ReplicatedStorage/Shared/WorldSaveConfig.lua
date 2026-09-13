-- Archive capacity is fixed; replacement and world-copy policy are decided by callers.
return {
	SchemaVersion = 1,
	ArchiveStore = "EcoshiftWorldArchives_Overhaul_20260912",
	ManifestStore = "EcoshiftWorldManifests_Overhaul_20260912",
	MaxSlots = 5,
	MaxRosterSize = 6,
	MaxNameCharacters = 32,
	MaxNameBytes = 128,
	DefaultName = "Untitled expedition",
	DataStoreAttempts = 3,
}
