package config

import (
	"os"
	"strconv"
)

type Config struct {
	Environment    string
	Port           string
	DBHost         string
	DBReadHost     string
	DBPort         string
	DBUser         string
	DBPassword     string
	DBName         string
	DBSSLMode      string
	DBMaxOpen      int
	DBMaxIdle      int
	DBReadMaxOpen  int
	DBReadMaxIdle  int
}

func LoadConfig() *Config {
	return &Config{
		Environment:   getEnv("GO_ENV", "development"),
		Port:          getEnv("PORT", "8001"),
		DBHost:        getEnv("PRODUCT_DB_HOST", "localhost"),
		DBReadHost:    getEnv("PRODUCT_DB_READ_HOST", ""),
		DBPort:        getEnv("PRODUCT_DB_PORT", "5432"),
		DBUser:        getEnv("PRODUCT_DB_USER", "ecommerce_user"),
		DBPassword:    getEnv("PRODUCT_DB_PASSWORD", "secure_password_123"),
		DBName:        getEnv("PRODUCT_DB_NAME", "products"),
		DBSSLMode:     getEnv("PRODUCT_DB_SSLMODE", "disable"),
		DBMaxOpen:     getEnvInt("PRODUCT_DB_MAX_OPEN_CONNS", 0),
		DBMaxIdle:     getEnvInt("PRODUCT_DB_MAX_IDLE_CONNS", 0),
		DBReadMaxOpen: getEnvInt("PRODUCT_DB_READ_MAX_OPEN_CONNS", 0),
		DBReadMaxIdle: getEnvInt("PRODUCT_DB_READ_MAX_IDLE_CONNS", 0),
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func getEnvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}
