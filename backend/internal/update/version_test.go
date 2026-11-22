package update

import "testing"

func TestCompareVersions(t *testing.T) {
	tests := []struct {
		name string
		a    string
		b    string
		want int
	}{
		{"equal", "3.7.10.0", "3.7.10.0", 0},
		{"fourth segment ignored", "3.7.10.1", "3.7.10.9", 0},
		{"newer", "3.7.10.0", "2.4.2.0", 1},
		{"older", "2.4.2.0", "3.7.10.0", -1},
		{"comma spelling", "2, 4, 2, 0", "2.4.2.0", 0},
		{"missing segments are zero", "2", "2.0.0", 0},
		{"missing segments on the right", "2.4.2", "2.4.2.0", 0},
		{"missing segment smaller", "2.4", "2.4.1", -1},
		{"unparsable is zero", "not-a-version", "0.0.0", 0},
		{"empty is zero", "", "0.0.0", 0},
		{"unparsable below everything", "garbage", "0.0.1", -1},
		{"three segments decide", "1.9.9", "2.0.0", -1},
		{"numeric not lexical", "10.0.0", "9.9.9", 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := compareVersions(tt.a, tt.b); got != tt.want {
				t.Errorf("compareVersions(%q, %q) = %d, want %d", tt.a, tt.b, got, tt.want)
			}
		})
	}
}

func TestBelowMinimum(t *testing.T) {
	tests := []struct {
		name     string
		filename string
		version  string
		want     bool
	}{
		{"dlss below floor", "nvngx_dlss.dll", "1.6.1.0", true},
		{"dlss at floor", "nvngx_dlss.dll", "2.0.0.0", false},
		{"dlss above floor", "nvngx_dlss.dll", "2.4.2.0", false},
		{"dlss filename case-insensitive", "NVNGX_DLSS.DLL", "1.6.1.0", true},
		{"unparsable dlss version counts as zero", "nvngx_dlss.dll", "not-a-version", true},
		{"other DLL has no floor", "libxess.dll", "1.0.0.0", false},
		{"frame generation DLL has no floor", "nvngx_dlssg.dll", "1.0.0.0", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := belowMinimum(tt.filename, tt.version); got != tt.want {
				t.Errorf("belowMinimum(%q, %q) = %v, want %v", tt.filename, tt.version, got, tt.want)
			}
		})
	}
}
