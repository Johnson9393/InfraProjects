package database

import (
	"fmt"
	"os"
	"product-service/config"
	"strings"
	"time"

	log "github.com/sirupsen/logrus"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Connections holds the writer and, when a distinct read host is set, the reader.
// Dev CNPG leaves the read host empty or equal to the writer, so both paths use one pool.
type Connections struct {
	Writer *gorm.DB
	Reader *gorm.DB
}

func (c *Connections) Read() *gorm.DB {
	if c.Reader != nil {
		return c.Reader
	}
	return c.Writer
}

func Connect(cfg *config.Config) *Connections {
	readHost := strings.TrimSpace(cfg.DBReadHost)
	split := readHost != "" && readHost != cfg.DBHost && !migrating()

	writerOpen, writerIdle := poolLimits(cfg.DBMaxOpen, cfg.DBMaxIdle, !split)
	writer := openPostgres(cfg, cfg.DBHost, writerOpen, writerIdle)

	if !split {
		log.Info("product reads and writes use the writer")
		return &Connections{Writer: writer}
	}

	readOpen, readIdle := poolLimits(cfg.DBReadMaxOpen, cfg.DBReadMaxIdle, false)
	reader := openPostgres(cfg, readHost, readOpen, readIdle)
	log.WithField("read_host", readHost).Info("product catalog reads use the read host; stock checks and writes use the writer")
	return &Connections{Writer: writer, Reader: reader}
}

func migrating() bool {
	return len(os.Args) > 1 && os.Args[1] == "migrate"
}

func poolLimits(maxOpen, maxIdle int, single bool) (int, int) {
	if maxOpen <= 0 {
		if single {
			maxOpen = 100
		} else {
			maxOpen = 20
		}
	}
	if maxIdle <= 0 {
		if single {
			maxIdle = 10
		} else {
			maxIdle = 5
		}
	}
	if maxIdle > maxOpen {
		maxIdle = maxOpen
	}
	return maxOpen, maxIdle
}

func openPostgres(cfg *config.Config, host string, maxOpen, maxIdle int) *gorm.DB {
	sslmode := cfg.DBSSLMode
	if sslmode == "" {
		sslmode = "disable"
	}

	dsn := fmt.Sprintf(
		"host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=UTC",
		dsnValue(host),
		dsnValue(cfg.DBUser),
		dsnValue(cfg.DBPassword),
		dsnValue(cfg.DBName),
		dsnValue(cfg.DBPort),
		dsnValue(sslmode),
	)

	var db *gorm.DB
	var err error

	for i := 0; i < 5; i++ {
		db, err = gorm.Open(postgres.New(postgres.Config{
			DSN:                  dsn,
			PreferSimpleProtocol: true,
		}), &gorm.Config{
			Logger:      logger.Default.LogMode(logger.Info),
			PrepareStmt: false,
		})

		if err == nil {
			log.WithField("host", host).Info("Successfully connected to database")
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
