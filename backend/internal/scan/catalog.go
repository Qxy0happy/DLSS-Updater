package scan

import "strings"

// dllCatalog is the known-technology filename set a scan reports, keyed by
// lower-case base name. The ids are stable lowercase catalog ids the frontend
// maps to display names; they never change inside dlss.v1.
var dllCatalog = map[string]string{
	"nvngx_dlss.dll":   "dlss",
	"nvngx_dlssg.dll":  "dlss_g",
	"nvngx_dlssd.dll":  "dlss_d",
	"nvngx_dlssnr.dll": "dlss_nr",

	"libxess.dll":      "xess",
	"libxess_dx11.dll": "xess_dx11",
	"libxess_fg.dll":   "xess_fg",
	"libxell.dll":      "xell",

	"sl.common.dll":     "streamline_common",
	"sl.dlss.dll":       "streamline_dlss",
	"sl.dlss_g.dll":     "streamline_dlss_g",
	"sl.interposer.dll": "streamline_interposer",
	"sl.pcl.dll":        "streamline_pcl",
	"sl.reflex.dll":     "streamline_reflex",
	"sl.directsr.dll":   "streamline_directsr",
	"sl.dlss_d.dll":     "streamline_dlss_d",
	"sl.nis.dll":        "streamline_nis",

	"amd_fidelityfx_vk.dll":                   "fsr_vk",
	"amd_fidelityfx_dx12.dll":                 "fsr_dx12",
	"amd_fidelityfx_upscaler_dx12.dll":        "fsr4_upscaler_dx12",
	"amd_fidelityfx_framegeneration_dx12.dll": "fsr4_framegeneration_dx12",
	"amd_fidelityfx_loader_dx12.dll":          "fsr4_loader_dx12",
	"amd_fidelityfx_upscaler_vk.dll":          "fsr4_upscaler_vk",
	"amd_fidelityfx_framegeneration_vk.dll":   "fsr4_framegeneration_vk",
	"amd_fidelityfx_loader_vk.dll":            "fsr4_loader_vk",
	"amd_fidelityfx_denoiser_dx12.dll":        "fsr_denoiser_dx12",
	"amd_fidelityfx_radiancecache_dx12.dll":   "fsr_radiancecache_dx12",
}

// skipDirectories mirrors the old application's non-game directory set. Names
// are compared lower-case against a directory basename.
var skipDirectories = map[string]struct{}{
	"__pycache__":  {},
	".git":         {},
	".svn":         {},
	".hg":          {},
	"node_modules": {},
	"logs":         {},
	"log":          {},
	"saves":        {},
	"save":         {},
	"screenshots":  {},
	"crash":        {},
	"crashdumps":   {},
	"dumps":        {},
	"temp":         {},
	"tmp":          {},
	"cache":        {},
	".cache":       {},
	"shader_cache": {},
	"shadercache":  {},
	"gpucache":     {},
	"webcache":     {},
}

// dllType returns the catalog id of filename, matching case-insensitively.
func dllType(filename string) (string, bool) {
	t, ok := dllCatalog[strings.ToLower(filename)]
	return t, ok
}

// skipDirectory reports whether a directory basename is on the non-game set.
func skipDirectory(name string) bool {
	_, ok := skipDirectories[strings.ToLower(name)]
	return ok
}
