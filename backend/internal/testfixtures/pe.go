// Package testfixtures builds synthetic files for tests: PE images carrying a
// chosen version resource, temporary Steam libraries and DLL source
// directories. Nothing here touches real user data; every builder writes
// below a t.TempDir() root.
//
// The package imports testing, so production code must never import it.
package testfixtures

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"unicode/utf16"

	"github.com/saferwall/pe"
)

// File versions the slice exercises. They are named by the role they play in
// an update decision, not by the library they imitate.
const (
	// VersionBelowMinimum is older than the 2.0.0 floor for nvngx_dlss.dll.
	VersionBelowMinimum = "1.6.1.0"
	// VersionAtMinimum is exactly the 2.0.0 floor.
	VersionAtMinimum = "2.0.0.0"
	// VersionInstalled is a typical installed game DLL.
	VersionInstalled = "2.4.2.0"
	// VersionUpdate is newer than VersionInstalled and a normal update source.
	VersionUpdate = "3.7.10.0"
	// VersionNewest is higher than every other fixture version.
	VersionNewest = "3.8.11.0"
)

// Known DLL base names used by the fixtures.
const (
	DLSSDLL  = "nvngx_dlss.dll"
	DLSSGDLL = "nvngx_dlssg.dll"
	XeSSDLL  = "libxess.dll"
	FSRDLL   = "amd_fidelityfx_dx12.dll"
)

// PEOptions controls a synthetic PE image.
type PEOptions struct {
	// Bits is 32 or 64. Zero means 64.
	Bits int
	// Version is a dotted file version with one to four numeric parts.
	Version string
}

// WritePE writes a synthetic PE DLL named name inside dir and returns the
// absolute path. The image carries a VS_VERSIONINFO resource whose fixed file
// info and FileVersion/ProductVersion strings are Version, normalized to four
// dotted numeric fields.
func WritePE(tb testing.TB, dir, name string, opts PEOptions) string {
	tb.Helper()
	return writeFixtureFile(tb, dir, name, buildPE(tb, opts))
}

// WriteCorruptFile writes bytes that are not a PE image and returns the path.
func WriteCorruptFile(tb testing.TB, dir, name string) string {
	tb.Helper()
	const body = "this fixture is intentionally not a portable executable\n"
	return writeFixtureFile(tb, dir, name, []byte(strings.Repeat(body, 8)))
}

// PEVersion reads the FileVersion of a synthetic or real PE with saferwall/pe,
// using the minimal option set that still parses the resource directory.
func PEVersion(tb testing.TB, path string) string {
	tb.Helper()
	f, err := pe.New(path, &pe.Options{
		OmitExportDirectory:       true,
		OmitImportDirectory:       true,
		OmitExceptionDirectory:    true,
		OmitSecurityDirectory:     true,
		OmitRelocDirectory:        true,
		OmitDebugDirectory:        true,
		OmitArchitectureDirectory: true,
		OmitGlobalPtrDirectory:    true,
		OmitTLSDirectory:          true,
		OmitLoadConfigDirectory:   true,
		OmitBoundImportDirectory:  true,
		OmitIATDirectory:          true,
		OmitDelayImportDirectory:  true,
		OmitCLRHeaderDirectory:    true,
		OmitCLRMetadata:           true,
	})
	if err != nil {
		tb.Fatalf("open PE %s: %v", path, err)
	}
	defer f.Close()
	if err := f.Parse(); err != nil {
		tb.Fatalf("parse PE %s: %v", path, err)
	}
	versions, err := f.ParseVersionResources()
	if err != nil {
		tb.Fatalf("read version resources of %s: %v", path, err)
	}
	return versions["FileVersion"]
}

const (
	peHeaderOffset  = 0x80
	fileAlignment   = 0x200
	sectionAlign    = 0x1000
	headersSize     = 0x200
	textRawOffset   = 0x200
	rsrcRawOffset   = 0x400
	textVirtualAddr = 0x1000
	rsrcVirtualAddr = 0x2000

	coffHeaderSize   = 20
	optional32Size   = 224
	optional64Size   = 240
	sectionHeaderLen = 40
	numberOfSections = 2

	imageFileDLL               = 0x2000
	imageFileExecutableImage   = 0x0002
	imageFile32BitMachine      = 0x0100
	imageScnCntCode            = 0x00000020
	imageScnMemExecute         = 0x20000000
	imageScnMemRead            = 0x40000000
	imageScnCntInitializedData = 0x00000040
	imageSubsystemWindowsCUI   = 3
)

func buildPE(tb testing.TB, opts PEOptions) []byte {
	tb.Helper()
	bits := opts.Bits
	if bits == 0 {
		bits = 64
	}
	if bits != 32 && bits != 64 {
		tb.Fatalf("PEOptions.Bits = %d, want 32 or 64", bits)
	}
	version := opts.Version
	if version == "" {
		version = "0.0.0.0"
	}
	parts := parseVersion(tb, version)

	rsrc := buildResourceSection(parts)
	rsrcRawSize := roundUp(uint32(len(rsrc)), fileAlignment)

	is64 := bits == 64
	optionalSize := uint32(optional32Size)
	if is64 {
		optionalSize = optional64Size
	}
	sectionTableOffset := uint32(peHeaderOffset) + 4 + coffHeaderSize + optionalSize
	fileSize := rsrcRawOffset + rsrcRawSize
	data := make([]byte, fileSize)

	// DOS header: MZ plus the e_lfanew pointer at 0x3C.
	data[0], data[1] = 'M', 'Z'
	binary.LittleEndian.PutUint32(data[0x3C:], peHeaderOffset)

	// NT signature and COFF file header.
	copy(data[peHeaderOffset:], []byte{'P', 'E', 0, 0})
	coff := uint32(peHeaderOffset) + 4
	machine := uint16(pe.ImageFileMachineI386)
	characteristics := uint32(imageFileDLL | imageFileExecutableImage)
	if is64 {
		machine = uint16(pe.ImageFileMachineAMD64)
	} else {
		characteristics |= imageFile32BitMachine
	}
	binary.LittleEndian.PutUint16(data[coff:], machine)
	binary.LittleEndian.PutUint16(data[coff+2:], numberOfSections)
	binary.LittleEndian.PutUint16(data[coff+16:], uint16(optionalSize))
	binary.LittleEndian.PutUint32(data[coff+18:], characteristics)

	// Optional header.
	opt := coff + coffHeaderSize
	if is64 {
		binary.LittleEndian.PutUint16(data[opt:], 0x20b)
		binary.LittleEndian.PutUint64(data[opt+24:], 0x180000000)
		binary.LittleEndian.PutUint32(data[opt+32:], sectionAlign)
		binary.LittleEndian.PutUint32(data[opt+36:], fileAlignment)
		binary.LittleEndian.PutUint16(data[opt+40:], 6) // MajorOperatingSystemVersion
		binary.LittleEndian.PutUint16(data[opt+48:], 6) // MajorSubsystemVersion
		binary.LittleEndian.PutUint32(data[opt+56:], 0x3000)
		binary.LittleEndian.PutUint32(data[opt+60:], headersSize)
		binary.LittleEndian.PutUint16(data[opt+68:], imageSubsystemWindowsCUI)
		binary.LittleEndian.PutUint64(data[opt+72:], 0x100000)
		binary.LittleEndian.PutUint64(data[opt+80:], 0x1000)
		binary.LittleEndian.PutUint64(data[opt+88:], 0x100000)
		binary.LittleEndian.PutUint64(data[opt+96:], 0x1000)
		binary.LittleEndian.PutUint32(data[opt+108:], 16)
		binary.LittleEndian.PutUint32(data[opt+112+2*8:], rsrcVirtualAddr)
		binary.LittleEndian.PutUint32(data[opt+112+2*8+4:], uint32(len(rsrc)))
	} else {
		binary.LittleEndian.PutUint16(data[opt:], 0x10b)
		binary.LittleEndian.PutUint32(data[opt+24:], textVirtualAddr) // BaseOfData
		binary.LittleEndian.PutUint32(data[opt+28:], 0x400000)
		binary.LittleEndian.PutUint32(data[opt+32:], sectionAlign)
		binary.LittleEndian.PutUint32(data[opt+36:], fileAlignment)
		binary.LittleEndian.PutUint16(data[opt+40:], 6)
		binary.LittleEndian.PutUint16(data[opt+48:], 6)
		binary.LittleEndian.PutUint32(data[opt+56:], 0x3000)
		binary.LittleEndian.PutUint32(data[opt+60:], headersSize)
		binary.LittleEndian.PutUint16(data[opt+68:], imageSubsystemWindowsCUI)
		binary.LittleEndian.PutUint32(data[opt+72:], 0x100000)
		binary.LittleEndian.PutUint32(data[opt+76:], 0x1000)
		binary.LittleEndian.PutUint32(data[opt+80:], 0x100000)
		binary.LittleEndian.PutUint32(data[opt+84:], 0x1000)
		binary.LittleEndian.PutUint32(data[opt+92:], 16)
		binary.LittleEndian.PutUint32(data[opt+96+2*8:], rsrcVirtualAddr)
		binary.LittleEndian.PutUint32(data[opt+96+2*8+4:], uint32(len(rsrc)))
	}

	// Section headers.
	writeSectionHeader(data[sectionTableOffset:], ".text",
		0x10, textVirtualAddr, fileAlignment, textRawOffset,
		imageScnCntCode|imageScnMemExecute|imageScnMemRead)
	writeSectionHeader(data[sectionTableOffset+sectionHeaderLen:], ".rsrc",
		uint32(len(rsrc)), rsrcVirtualAddr, rsrcRawSize, rsrcRawOffset,
		imageScnCntInitializedData|imageScnMemRead)

	// Section bodies: a single ret in .text, the resource tree in .rsrc.
	data[textRawOffset] = 0xC3
	copy(data[rsrcRawOffset:], rsrc)
	return data
}

func writeSectionHeader(dst []byte, name string, virtualSize, virtualAddr, rawSize, rawOffset uint32, characteristics uint32) {
	copy(dst[:8], name)
	binary.LittleEndian.PutUint32(dst[8:], virtualSize)
	binary.LittleEndian.PutUint32(dst[12:], virtualAddr)
	binary.LittleEndian.PutUint32(dst[16:], rawSize)
	binary.LittleEndian.PutUint32(dst[20:], rawOffset)
	binary.LittleEndian.PutUint32(dst[36:], characteristics)
}

func parseVersion(tb testing.TB, version string) [4]uint16 {
	tb.Helper()
	fields := strings.FieldsFunc(version, func(r rune) bool { return r == '.' || r == ',' })
	if len(fields) == 0 || len(fields) > 4 {
		tb.Fatalf("version %q must have one to four numeric parts", version)
	}
	var parts [4]uint16
	for i, field := range fields {
		n, err := strconv.ParseUint(field, 10, 16)
		if err != nil {
			tb.Fatalf("version %q part %q is not a 16-bit number", version, field)
		}
		parts[i] = uint16(n)
	}
	return parts
}

// buildResourceSection lays out one RT_VERSION resource:
//
//	0x00 root directory   (type 16)
//	0x18 type directory   (name 1)
//	0x30 name directory   (lang 0x0409)
//	0x48 data entry       -> blob at 0x58
//
// The offsets and the blob layout follow the alignment rules of
// IMAGE_RESOURCE_DIRECTORY and VS_VERSIONINFO.
func buildResourceSection(parts [4]uint16) []byte {
	blob := buildVersionInfo(parts)
	const (
		typeDirOffset   = 24
		nameDirOffset   = 48
		dataEntryOffset = 72
		blobOffset      = 88
	)
	rsrc := make([]byte, 0, blobOffset+len(blob))

	rsrc = append(rsrc, resourceDirectory(0, 1)...)
	rsrc = appendU32(rsrc, pe.VersionResourceType)
	rsrc = appendU32(rsrc, 0x80000000|typeDirOffset)

	rsrc = append(rsrc, resourceDirectory(0, 1)...)
	rsrc = appendU32(rsrc, 1)
	rsrc = appendU32(rsrc, 0x80000000|nameDirOffset)

	rsrc = append(rsrc, resourceDirectory(0, 1)...)
	rsrc = appendU32(rsrc, 0x0409)
	rsrc = appendU32(rsrc, dataEntryOffset)

	rsrc = appendU32(rsrc, rsrcVirtualAddr+blobOffset) // OffsetToData (RVA)
	rsrc = appendU32(rsrc, uint32(len(blob)))          // Size
	rsrc = appendU32(rsrc, 1200)                       // CodePage
	rsrc = appendU32(rsrc, 0)                          // Reserved

	rsrc = append(rsrc, blob...)
	return rsrc
}

func resourceDirectory(named, ids uint16) []byte {
	b := make([]byte, 16)
	binary.LittleEndian.PutUint16(b[12:], named)
	binary.LittleEndian.PutUint16(b[14:], ids)
	return b
}

func appendU32(b []byte, v uint32) []byte {
	return binary.LittleEndian.AppendUint32(b, v)
}

// buildVersionInfo returns a VS_VERSIONINFO blob with a VS_FIXEDFILEINFO and a
// StringFileInfo table carrying FileVersion and ProductVersion.
func buildVersionInfo(parts [4]uint16) []byte {
	versionText := formatVersion(parts)

	var b []byte
	b = append(b, 0, 0, 0, 0, 0, 0) // Length, ValueLength, Type filled below
	key := utf16Bytes("VS_VERSION_INFO")
	binary.LittleEndian.PutUint16(b[2:], uint16(len(key))) // ValueLength counts the key bytes
	b = append(b, key...)
	b = padTo4(b)

	b = appendFixedFileInfo(b, parts)

	stringFileInfoStart := len(b)
	b = append(b, 0, 0, 0, 0, 0, 0)
	b = append(b, utf16Bytes("StringFileInfo")...)
	b = padTo4(b)

	stringTableStart := len(b)
	b = append(b, 0, 0, 0, 0, 0, 0)
	b = append(b, utf16Bytes("040904B0")...)
	b = padTo4(b)

	b = appendVersionString(b, "FileVersion", versionText)
	b = appendVersionString(b, "ProductVersion", versionText)

	end := len(b)
	binary.LittleEndian.PutUint16(b[stringTableStart:], uint16(end-stringTableStart))
	binary.LittleEndian.PutUint16(b[stringFileInfoStart:], uint16(end-stringFileInfoStart))
	binary.LittleEndian.PutUint16(b[0:], uint16(end))
	return b
}

func appendFixedFileInfo(b []byte, parts [4]uint16) []byte {
	start := len(b)
	b = append(b, make([]byte, 52)...)
	le := binary.LittleEndian
	le.PutUint32(b[start+0:], 0xFEEF04BD)
	le.PutUint32(b[start+4:], 0x00010000)
	le.PutUint32(b[start+8:], uint32(parts[0])<<16|uint32(parts[1]))
	le.PutUint32(b[start+12:], uint32(parts[2])<<16|uint32(parts[3]))
	le.PutUint32(b[start+16:], uint32(parts[0])<<16|uint32(parts[1]))
	le.PutUint32(b[start+20:], uint32(parts[2])<<16|uint32(parts[3]))
	le.PutUint32(b[start+24:], 0x3F)    // FileFlagMask
	le.PutUint32(b[start+28:], 0)       // FileFlags
	le.PutUint32(b[start+32:], 0x40004) // VOS_NT_WINDOWS32
	le.PutUint32(b[start+36:], 1)       // VFT_DLL
	return b
}

// appendVersionString appends one String structure. Its Length covers the
// header, the UTF-16 key, the padding before the value and the value itself,
// which is where the version reader expects the next string to start.
func appendVersionString(b []byte, key, value string) []byte {
	start := len(b)
	b = append(b, 0, 0, 0, 0, 0, 0)
	keyBytes := utf16Bytes(key)
	binary.LittleEndian.PutUint16(b[start+2:], uint16(len(utf16.Encode([]rune(value)))+1))
	b = append(b, keyBytes...)
	b = padTo4(b)
	b = append(b, utf16Bytes(value)...)
	b = padTo4(b)
	binary.LittleEndian.PutUint16(b[start:], uint16(len(b)-start))
	return b
}

// formatVersion renders all four fields so string and fixed versions agree.
func formatVersion(parts [4]uint16) string {
	return strings.Join([]string{
		strconv.Itoa(int(parts[0])),
		strconv.Itoa(int(parts[1])),
		strconv.Itoa(int(parts[2])),
		strconv.Itoa(int(parts[3])),
	}, ".")
}

// utf16Bytes returns s as little-endian UTF-16 including a NUL terminator.
func utf16Bytes(s string) []byte {
	units := utf16.Encode([]rune(s))
	out := make([]byte, 0, (len(units)+1)*2)
	for _, u := range units {
		out = binary.LittleEndian.AppendUint16(out, u)
	}
	return append(out, 0, 0)
}

func padTo4(b []byte) []byte {
	for len(b)%4 != 0 {
		b = append(b, 0)
	}
	return b
}

func roundUp(n, alignment uint32) uint32 {
	return (n + alignment - 1) / alignment * alignment
}

// writeFixtureFile writes data to dir/name, creating dir when missing.
func writeFixtureFile(tb testing.TB, dir, name string, data []byte) string {
	tb.Helper()
	if !filepath.IsAbs(dir) {
		tb.Fatalf("fixture dir %q must be absolute", dir)
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		tb.Fatalf("create fixture dir %s: %v", dir, err)
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		tb.Fatalf("write fixture %s: %v", path, err)
	}
	return path
}
