package peversion

import "testing"

func TestNormalize(t *testing.T) {
	tests := map[string]string{
		"2.4.2.0":       "2.4.2.0",
		"2, 4, 2, 0":    "2.4.2.0",
		" 3,10,5,0 ":    "3.10.5.0",
		"1.0":           "1.0",
		"":              Zero,
		"   ":           Zero,
		"not-a-version": Zero,
		"1..2":          Zero,
		"1.2-beta":      Zero,
	}
	for raw, want := range tests {
		if got := Normalize(raw); got != want {
			t.Errorf("Normalize(%q) = %q, want %q", raw, got, want)
		}
	}
}
