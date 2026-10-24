package database

import (
	"fmt"
	"order-service/config"
	"strings"
	"time"

	log "github.com/sirupsen/logrus"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func Connect(cfg *config.Config) *gorm.DB {
	readHost := strings.TrimSpace(cfg.DBReadHost)
	if readHost != "" && readHost != cfg.DBHost {
		log.WithField("read_host", readHost).Info("order reads and writes stay on the writer so a replica cannot hide an order that was just created")
	}

	sslmode := cfg.DBSSLMode
	if sslmode == "" {
		sslmode = "disable"
	}

	maxOpen := cfg.DBMaxOpen
	if maxOpen <= 0 {
		maxOpen = 100
	}
	maxIdle := cfg.DBMaxIdle
	if maxIdle <= 0 {
		maxIdle = 10
	}
	if maxIdle > maxOpen {
		maxIdle = maxOpen
	}

	dsn := fmt.Sprintf(
		"host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=UTC",
		dsnValue(cfg.DBHost),
		dsnValue(cfg.DBUser),
		dsnValue(cfg.DBPassword),
		dsnValue(cfg.DBName),
		dsnValue(cfg.DBPort),
		dsnValue(sslmode),
	)

	var db *gorm.DB
	var err error

	// Retry connection up to 5 times
	for i := 0; i < 5; i++ {
		db, err = gorm.Open(postgres.New(postgres.Config{
			DSN:                  dsn,
			PreferSimpleProtocol: true,
		}), &gorm.Config{
			Logger:      logger.Default.LogMode(logger.Info),
			PrepareStmt: false,
		})

		if err == nil {
			log.Info("Successfully connected to database")
			break
		}

		log.WithError(err).Warnf("Failed to connect to database, retrying... (attempt %d/5)", i+1)
		time.Sleep(time.Second * 5)
	}

	if err != nil {
		log.WithError(err).Fatal("Failed to connect to database after 5 attempts")
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.WithError(err).Fatal("Failed to get database instance")
	}

	sqlDB.SetMaxIdleConns(maxIdle)
	sqlDB.SetMaxOpenConns(maxOpen)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)

	return db
}

func dsnValue(v string) string {
	if !strings.ContainsAny(v, " '\\") {
		return v
	}
	return "'" + strings.ReplaceAll(v, "'", "''") + "'"
}
