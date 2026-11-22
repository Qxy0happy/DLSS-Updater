// Package protomap converts stored rows to their dlss.v1 wire form. Scan
// events, the library and the backup service share it so ids, timestamps and
// the on-disk existence flag never drift between responses.
package protomap

import (
	"strconv"

	"google.golang.org/protobuf/types/known/timestamppb"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/fileops"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
)

// Game converts a stored game and its DLLs to the wire form.
func Game(g store.Game) *dlssv1.Game {
	out := &dlssv1.Game{
		Id:          strconv.FormatInt(g.ID, 10),
		AppId:       g.AppID,
		Name:        g.Name,
		InstallPath: g.Path,
		LibraryPath: g.LibraryPath,
		Dlls:        make([]*dlssv1.GameDLL, 0, len(g.DLLs)),
	}
	for _, d := range g.DLLs {
		out.Dlls = append(out.Dlls, DLL(d))
	}
	return out
}

// DLL converts a stored DLL to the wire form, including the on-disk existence
// check that clients use to flag missing targets.
func DLL(d store.DLL) *dlssv1.GameDLL {
	out := &dlssv1.GameDLL{
		Id:             strconv.FormatInt(d.ID, 10),
		GameId:         strconv.FormatInt(d.GameID, 10),
		DllType:        d.Type,
		Filename:       d.Filename,
		Path:           d.Path,
		CurrentVersion: d.CurrentVersion,
		Exists:         fileops.Exists(d.Path),
	}
	if d.MissingAt != nil {
		out.MissingAt = timestamppb.New(*d.MissingAt)
	}
	return out
}
