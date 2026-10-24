package database

import "testing"

func TestSplitSQL(t *testing.T) {
	parts := splitSQL("-- comment\nCREATE TABLE IF NOT EXISTS t (id int);\nCREATE INDEX IF NOT EXISTS i ON t (id);\n")
	if len(parts) != 2 {
		t.Fatalf("expected 2 statements, got %d", len(parts))
	}
	if parts[0] != "CREATE TABLE IF NOT EXISTS t (id int)" {
		t.Fatalf("unexpected statement %q", parts[0])
	}
}
