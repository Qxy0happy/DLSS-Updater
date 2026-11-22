package contract_test

import (
	"errors"
	"testing"

	"google.golang.org/genproto/googleapis/rpc/errdetails"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
)

func TestCodeForReason(t *testing.T) {
	tests := []struct {
		reason contract.Reason
		want   codes.Code
	}{
		{contract.ReasonAlreadyRunning, codes.FailedPrecondition},
		{contract.ReasonScanRootInvalid, codes.InvalidArgument},
		{contract.ReasonScanInProgress, codes.FailedPrecondition},
		{contract.ReasonUpdateInProgress, codes.FailedPrecondition},
		{contract.ReasonTargetMissing, codes.NotFound},
		{contract.ReasonSourceMissing, codes.NotFound},
		{contract.ReasonPermissionDenied, codes.PermissionDenied},
		{contract.ReasonVersionMismatch, codes.FailedPrecondition},
		{contract.ReasonBackupMissing, codes.NotFound},
		{contract.ReasonBackupCorrupt, codes.FailedPrecondition},
		{contract.ReasonTargetFolderMissing, codes.NotFound},
		{contract.ReasonMetadataStale, codes.Aborted},
		{contract.ReasonCancelled, codes.Canceled},
		{contract.ReasonInternal, codes.Internal},
		{"NOT_A_REASON", codes.Internal},
	}

	for _, tc := range tests {
		t.Run(string(tc.reason), func(t *testing.T) {
			if got := tc.reason.Code(); got != tc.want {
				t.Fatalf("Reason(%q).Code() = %v, want %v", tc.reason, got, tc.want)
			}
		})
	}
}

func TestReasonsAreTheStableSet(t *testing.T) {
	want := []contract.Reason{
		contract.ReasonAlreadyRunning,
		contract.ReasonScanRootInvalid,
		contract.ReasonScanInProgress,
		contract.ReasonUpdateInProgress,
		contract.ReasonTargetMissing,
		contract.ReasonSourceMissing,
		contract.ReasonPermissionDenied,
		contract.ReasonVersionMismatch,
		contract.ReasonBackupMissing,
		contract.ReasonBackupCorrupt,
		contract.ReasonTargetFolderMissing,
		contract.ReasonMetadataStale,
		contract.ReasonCancelled,
		contract.ReasonInternal,
	}
	if len(contract.Reasons) != len(want) {
		t.Fatalf("len(Reasons) = %d, want %d", len(contract.Reasons), len(want))
	}
	for i, reason := range want {
		if contract.Reasons[i] != reason {
			t.Fatalf("Reasons[%d] = %q, want %q", i, contract.Reasons[i], reason)
		}
		if !reason.Valid() {
			t.Fatalf("%q.Valid() = false", reason)
		}
	}
	if contract.Reason("NOT_A_REASON").Valid() {
		t.Fatal("unknown reason reported valid")
	}
}

func TestDetailErrorInfo(t *testing.T) {
	tests := []struct {
		name      string
		detail    contract.Detail
		wantPath  string
		wantRetry string
	}{
		{
			name:      "with path and retryable",
			detail:    contract.Detail{Reason: contract.ReasonPermissionDenied, Path: "/games/a.dll", Retryable: true},
			wantPath:  "/games/a.dll",
			wantRetry: "true",
		},
		{
			name:      "without path is omitted",
			detail:    contract.Detail{Reason: contract.ReasonAlreadyRunning},
			wantRetry: "false",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			info := tc.detail.ErrorInfo()
			if info.GetDomain() != contract.Domain {
				t.Fatalf("domain = %q, want %q", info.GetDomain(), contract.Domain)
			}
			if info.GetReason() != string(tc.detail.Reason) {
				t.Fatalf("reason = %q, want %q", info.GetReason(), tc.detail.Reason)
			}
			meta := info.GetMetadata()
			if meta["retryable"] != tc.wantRetry {
				t.Fatalf("metadata[retryable] = %q, want %q", meta["retryable"], tc.wantRetry)
			}
			if tc.wantPath == "" {
				if _, ok := meta["path"]; ok {
					t.Fatalf("metadata[path] present for pathless error: %#v", meta)
				}
			} else if meta["path"] != tc.wantPath {
				t.Fatalf("metadata[path] = %q, want %q", meta["path"], tc.wantPath)
			}
		})
	}
}

func TestDetailErrRoundTrip(t *testing.T) {
	want := contract.Detail{
		Reason:    contract.ReasonTargetMissing,
		Path:      "/games/missing.dll",
		Retryable: false,
	}
	err := want.Err("The target file no longer exists.")
	if status.Code(err) != codes.NotFound {
		t.Fatalf("status.Code(err) = %v, want NotFound", status.Code(err))
	}
	if got := status.Convert(err).Message(); got != "The target file no longer exists." {
		t.Fatalf("message = %q", got)
	}

	st := status.Convert(err)
	if len(st.Details()) != 1 {
		t.Fatalf("details = %#v, want exactly one", st.Details())
	}
	info, ok := st.Details()[0].(*errdetails.ErrorInfo)
	if !ok {
		t.Fatalf("detail type = %T, want *errdetails.ErrorInfo", st.Details()[0])
	}
	if info.GetReason() != string(want.Reason) {
		t.Fatalf("detail reason = %q", info.GetReason())
	}

	got, ok := contract.FromError(err)
	if !ok {
		t.Fatal("FromError() did not find a contract detail")
	}
	if got != want {
		t.Fatalf("FromError() = %+v, want %+v", got, want)
	}
}

func TestFromErrorRejectsForeignErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
	}{
		{name: "nil", err: nil},
		{name: "plain error", err: errors.New("boom")},
		{name: "status without details", err: status.Error(codes.Internal, "boom")},
		{
			name: "foreign domain",
			err: func() error {
				st, stErr := status.New(codes.Internal, "boom").WithDetails(&errdetails.ErrorInfo{
					Domain: "other",
					Reason: "INTERNAL",
				})
				if stErr != nil {
					t.Fatalf("WithDetails: %v", stErr)
				}
				return st.Err()
			}(),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if _, ok := contract.FromError(tc.err); ok {
				t.Fatalf("FromError(%v) reported a contract detail", tc.err)
			}
		})
	}
}

func TestUnknownReasonNormalizesToInternal(t *testing.T) {
	detail := contract.Detail{Reason: "SOMETHING_ELSE"}
	if got := detail.ErrorInfo().GetReason(); got != string(contract.ReasonInternal) {
		t.Fatalf("unknown reason encoded as %q, want %q", got, contract.ReasonInternal)
	}
}
