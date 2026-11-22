package update

import (
	"errors"
	"io/fs"
	"syscall"
	"testing"
)

func TestFileReasonMapsWriteFailuresToStableItemReasons(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		fallback string
		want     string
	}{
		{
			name:     "permission denied",
			err:      &fs.PathError{Op: "open", Path: "/game/dll", Err: fs.ErrPermission},
			fallback: reasonInternal,
			want:     reasonPermissionDenied,
		},
		{
			name:     "read-only filesystem",
			err:      syscall.EROFS,
			fallback: reasonInternal,
			want:     reasonPermissionDenied,
		},
		{
			name:     "no space left on device is internal",
			err:      syscall.ENOSPC,
			fallback: reasonSourceMissing,
			want:     reasonInternal,
		},
		{
			name:     "io error is internal",
			err:      syscall.EIO,
			fallback: reasonSourceMissing,
			want:     reasonInternal,
		},
		{
			name:     "unexpected write error is internal",
			err:      errors.New("copy failed"),
			fallback: reasonSourceMissing,
			want:     reasonInternal,
		},
		{
			name:     "vanished source keeps the caller reason",
			err:      &fs.PathError{Op: "open", Path: "/source/dll", Err: fs.ErrNotExist},
			fallback: reasonSourceMissing,
			want:     reasonSourceMissing,
		},
		{
			name:     "vanished target keeps the caller reason",
			err:      &fs.PathError{Op: "open", Path: "/game/dll", Err: fs.ErrNotExist},
			fallback: reasonTargetMissing,
			want:     reasonTargetMissing,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := fileReason(tt.err, tt.fallback); got != tt.want {
				t.Errorf("fileReason(%v, %q) = %q, want %q", tt.err, tt.fallback, got, tt.want)
			}
		})
	}
}
