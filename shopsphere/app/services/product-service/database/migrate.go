package database

import (
	"embed"
	"fmt"
	"sort"
	"strings"

	log "github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

// ApplyMigrations runs unapplied SQL files against the writer.
// Existing tables are left in place: baseline SQL uses IF NOT EXISTS.
func ApplyMigrations(db *gorm.DB) error {
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}

	if _, err := sqlDB.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version text PRIMARY KEY,
		applied_at timestamptz NOT NULL DEFAULT now()
	)`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	entries, err := migrationFiles.ReadDir("migrations")
	if err != nil {
		return err
	}

	names := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".sql") {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)

	for _, name := range names {
		version := strings.TrimSuffix(name, ".sql")

		var count int
		if err := sqlDB.QueryRow(`SELECT COUNT(*) FROM schema_migrations WHERE version = $1`, version).Scan(&count); err != nil {
			return err
		}
		if count > 0 {
			log.WithField("version", version).Info("migration already applied")
			continue
		}

		body, err := migrationFiles.ReadFile("migrations/" + name)
		if err != nil {
			return err
		}

		tx, err := sqlDB.Begin()
		if err != nil {
			return err
		}

		for _, stmt := range splitSQL(string(body)) {
			if _, err := tx.Exec(stmt); err != nil {
				_ = tx.Rollback()
				return fmt.Errorf("migration %s: %w", version, err)
			}
		}

		if _, err := tx.Exec(`INSERT INTO schema_migrations (version) VALUES ($1)`, version); err != nil {
			_ = tx.Rollback()
			return err
		}
		if err := tx.Commit(); err != nil {
			return err
		}

		log.WithField("version", version).Info("migration applied")
	}

	return nil
}

func splitSQL(script string) []string {
	var b strings.Builder
	var out []string

	for _, line := range strings.Split(script, "\n") {
		trim := strings.TrimSpace(line)
		if strings.HasPrefix(trim, "--") {
			continue
		}
		b.WriteString(line)
		b.WriteString("\n")
		if strings.HasSuffix(trim, ";") {
			stmt := strings.TrimSpace(b.String())
			stmt = strings.TrimSuffix(stmt, ";")
			stmt = strings.TrimSpace(stmt)
			if stmt != "" {
				out = append(out, stmt)
			}
			b.Reset()
		}
	}

	rest := strings.TrimSpace(b.String())
	rest = strings.TrimSuffix(rest, ";")
	rest = strings.TrimSpace(rest)
	if rest != "" {
		out = append(out, rest)
	}
	return out
}
