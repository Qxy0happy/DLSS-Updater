//go:build !integration

package backup

// postReplaceCheck is the restore's verification point after the target has
// been replaced. Production builds and tests drive the real file only; the
// integration build can force a deterministic failure to prove the rollback.
func postReplaceCheck(string) error { return nil }
