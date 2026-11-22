// Package contract owns the stable wire-level error convention of dlss.v1.
//
// Every non-OK gRPC status carries google.rpc.ErrorInfo with domain "dlss.v1",
// a stable reason, and metadata "path"/"retryable". Clients switch on the
// reason and never parse the human-readable status message.
package contract

import (
	"google.golang.org/genproto/googleapis/rpc/errdetails"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Domain is the ErrorInfo domain carried by every contract error.
const Domain = "dlss.v1"

// ProtoVersion is the contract version reported by Daemon.GetStatus.
const ProtoVersion = "dlss.v1"

// Reason is a stable, machine-readable error identifier. Its string values are
// part of the public contract and must never change.
type Reason string

// The stable reason set of dlss.v1.
const (
	ReasonAlreadyRunning      Reason = "ALREADY_RUNNING"
	ReasonScanRootInvalid     Reason = "SCAN_ROOT_INVALID"
	ReasonScanInProgress      Reason = "SCAN_IN_PROGRESS"
	ReasonUpdateInProgress    Reason = "UPDATE_IN_PROGRESS"
	ReasonTargetMissing       Reason = "TARGET_MISSING"
	ReasonSourceMissing       Reason = "SOURCE_MISSING"
	ReasonPermissionDenied    Reason = "PERMISSION_DENIED"
	ReasonVersionMismatch     Reason = "VERSION_MISMATCH"
	ReasonBackupMissing       Reason = "BACKUP_MISSING"
	ReasonBackupCorrupt       Reason = "BACKUP_CORRUPT"
	ReasonTargetFolderMissing Reason = "TARGET_FOLDER_MISSING"
	ReasonMetadataStale       Reason = "METADATA_STALE"
	ReasonCancelled           Reason = "CANCELLED"
	ReasonInternal            Reason = "INTERNAL"
)

// Reasons is the complete stable reason set, in documentation order.
var Reasons = []Reason{
	ReasonAlreadyRunning,
	ReasonScanRootInvalid,
	ReasonScanInProgress,
	ReasonUpdateInProgress,
	ReasonTargetMissing,
	ReasonSourceMissing,
	ReasonPermissionDenied,
	ReasonVersionMismatch,
	ReasonBackupMissing,
	ReasonBackupCorrupt,
	ReasonTargetFolderMissing,
	ReasonMetadataStale,
	ReasonCancelled,
	ReasonInternal,
}

// Valid reports whether r belongs to the stable reason set.
func (r Reason) Valid() bool {
	for _, known := range Reasons {
		if known == r {
			return true
		}
	}
	return false
}

// normalized maps an unknown reason to INTERNAL so the wire never carries a
// value outside the documented set.
func (r Reason) normalized() Reason {
	if r.Valid() {
		return r
	}
	return ReasonInternal
}

// Code is the gRPC status code that accompanies the reason.
func (r Reason) Code() codes.Code {
	switch r.normalized() {
	case ReasonScanRootInvalid:
		return codes.InvalidArgument
	case ReasonTargetMissing, ReasonSourceMissing, ReasonBackupMissing, ReasonTargetFolderMissing:
		return codes.NotFound
	case ReasonPermissionDenied:
		return codes.PermissionDenied
	case ReasonMetadataStale:
		return codes.Aborted
	case ReasonCancelled:
		return codes.Canceled
	case ReasonAlreadyRunning, ReasonScanInProgress, ReasonUpdateInProgress, ReasonVersionMismatch, ReasonBackupCorrupt:
		return codes.FailedPrecondition
	default:
		return codes.Internal
	}
}

// Detail is the payload of a contract error, independent of its message.
type Detail struct {
	Reason Reason
	// Path is the filesystem path the error is about; empty when not applicable.
	Path string
	// Retryable tells the client whether retrying the same operation may work.
	Retryable bool
}

// ErrorInfo builds the wire representation of the detail.
func (d Detail) ErrorInfo() *errdetails.ErrorInfo {
	metadata := map[string]string{
		"retryable": "false",
	}
	if d.Retryable {
		metadata["retryable"] = "true"
	}
	if d.Path != "" {
		metadata["path"] = d.Path
	}
	return &errdetails.ErrorInfo{
		Domain:   Domain,
		Reason:   string(d.Reason.normalized()),
		Metadata: metadata,
	}
}

// Status builds a gRPC status with the reason's code, the user-facing message
// and the ErrorInfo detail.
func (d Detail) Status(message string) *status.Status {
	st := status.New(d.Reason.Code(), message)
	withDetails, err := st.WithDetails(d.ErrorInfo())
	if err != nil {
		// The detail is a well-known type and cannot fail in practice; falling
		// back to the bare status keeps the call total.
		return st
	}
	return withDetails
}

// Err builds a gRPC status error; suitable for returning from a handler.
func (d Detail) Err(message string) error {
	return d.Status(message).Err()
}

// FromStatus extracts the contract detail from st.
func FromStatus(st *status.Status) (Detail, bool) {
	if st == nil {
		return Detail{}, false
	}
	for _, any := range st.Details() {
		info, ok := any.(*errdetails.ErrorInfo)
		if !ok || info.GetDomain() != Domain {
			continue
		}
		detail := Detail{
			Reason:    Reason(info.GetReason()),
			Path:      info.GetMetadata()["path"],
			Retryable: info.GetMetadata()["retryable"] == "true",
		}
		return detail, true
	}
	return Detail{}, false
}

// FromError extracts the contract detail from err, if it carries one.
func FromError(err error) (Detail, bool) {
	if err == nil {
		return Detail{}, false
	}
	st, ok := status.FromError(err)
	if !ok {
		return Detail{}, false
	}
	return FromStatus(st)
}
