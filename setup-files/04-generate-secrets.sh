 #!/bin/bash

# Get variables from the main script via arguments
USER_EMAIL=$1
DOMAIN_NAME=$2
GENERIC_TIMEZONE=$3

if [ -z "$USER_EMAIL" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "ERROR: Email or domain name not specified"
  echo "Usage: $0 user@example.com example.com [timezone]"
  exit 1
fi

if [ -z "$GENERIC_TIMEZONE" ]; then
  GENERIC_TIMEZONE="UTC"
fi

echo "Generating secret keys and passwords..."

# Function to generate random strings
generate_random_string() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | fold -w ${length} | head -n 1
}

# Function to generate safe passwords (no special bash characters)
generate_safe_password() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# Generating keys and passwords
N8N_ENCRYPTION_KEY=$(generate_random_string 40)
if [ -z "$N8N_ENCRYPTION_KEY" ]; then
  echo "ERROR: Failed to generate encryption key for n8n"
  exit 1
fi

N8N_USER_MANAGEMENT_JWT_SECRET=$(generate_random_string 40)
if [ -z "$N8N_USER_MANAGEMENT_JWT_SECRET" ]; then
  echo "ERROR: Failed to generate JWT secret for n8n"
  exit 1
fi

# Use safer password generation function (alphanumeric only)
N8N_PASSWORD=$(generate_safe_password 16)
if [ -z "$N8N_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for n8n"
  exit 1
fi

FLOWISE_PASSWORD=$(generate_safe_password 16)
if [ -z "$FLOWISE_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for Flowise"
  exit 1
fi

# PostgreSQL Credentials
POSTGRES_DB="n8n" # Default database name
POSTGRES_USER="n8n" # Default username
POSTGRES_PASSWORD=$(generate_safe_password 16)
if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for PostgreSQL"
  exit 1
fi

# --- Generate Qdrant Credentials (Optional) ---
# Qdrant can run without an API key for internal network access.
# Generate one for optional security layer.
QDRANT_API_KEY=$(openssl rand -hex 32)

# Generate a random CRAWL4AI_JWT_SECRET
CRAWL4AI_JWT_SECRET=$(openssl rand -hex 32)

# Generate WAHA credentials
WAHA_API_USERNAME="admin"
WAHA_API_PASSWORD=$(generate_safe_password 16)
if [ -z "$WAHA_API_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for WAHA"
  exit 1
fi

# Debug output for all variables
set +x
echo "[DEBUG] N8N_ENCRYPTION_KEY: $N8N_ENCRYPTION_KEY"
echo "[DEBUG] N8N_USER_MANAGEMENT_JWT_SECRET: $N8N_USER_MANAGEMENT_JWT_SECRET"
echo "[DEBUG] N8N_DEFAULT_USER_EMAIL: $USER_EMAIL"
echo "[DEBUG] N8N_DEFAULT_USER_PASSWORD: $N8N_PASSWORD"
echo "[DEBUG] GENERIC_TIMEZONE: $GENERIC_TIMEZONE"
echo "[DEBUG] FLOWISE_PASSWORD: $FLOWISE_PASSWORD"
echo "[DEBUG] POSTGRES_DB: $POSTGRES_DB"
echo "[DEBUG] POSTGRES_USER: $POSTGRES_USER"
echo "[DEBUG] POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
echo "[DEBUG] DOMAIN_NAME: $DOMAIN_NAME"
echo "[DEBUG] QDRANT_API_KEY: $QDRANT_API_KEY"
echo "[DEBUG] CRAWL4AI_JWT_SECRET: $CRAWL4AI_JWT_SECRET"
echo "[DEBUG] WAHA_API_USERNAME: $WAHA_API_USERNAME"
echo "[DEBUG] WAHA_API_PASSWORD: $WAHA_API_PASSWORD"
set -x

# Abort if any required variable is empty
if [ -z "$N8N_ENCRYPTION_KEY" ] || [ -z "$N8N_USER_MANAGEMENT_JWT_SECRET" ] || [ -z "$USER_EMAIL" ] || [ -z "$N8N_PASSWORD" ] || [ -z "$FLOWISE_PASSWORD" ] || [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$QDRANT_API_KEY" ] || [ -z "$CRAWL4AI_JWT_SECRET" ] || [ -z "$WAHA_API_USERNAME" ] || [ -z "$WAHA_API_PASSWORD" ]; then
  echo "[ERROR] One or more required variables are empty. Aborting .env generation." >&2
  exit 1
fi

# Escape all values for .env before heredoc
N8N_ENCRYPTION_KEY_ESCAPED=$(printf '%s' "$N8N_ENCRYPTION_KEY" | sed 's/"/\\"/g')
N8N_USER_MANAGEMENT_JWT_SECRET_ESCAPED=$(printf '%s' "$N8N_USER_MANAGEMENT_JWT_SECRET" | sed 's/"/\\"/g')
N8N_DEFAULT_USER_EMAIL_ESCAPED=$(printf '%s' "$USER_EMAIL" | sed 's/"/\\"/g')
N8N_PASSWORD_ESCAPED=$(printf '%s' "$N8N_PASSWORD" | sed 's/"/\\"/g')
GENERIC_TIMEZONE_ESCAPED=$(printf '%s' "$GENERIC_TIMEZONE" | sed 's/"/\\"/g')
FLOWISE_PASSWORD_ESCAPED=$(printf '%s' "$FLOWISE_PASSWORD" | sed 's/"/\\"/g')
POSTGRES_DB_ESCAPED=$(printf '%s' "$POSTGRES_DB" | sed 's/"/\\"/g')
POSTGRES_USER_ESCAPED=$(printf '%s' "$POSTGRES_USER" | sed 's/"/\\"/g')
POSTGRES_PASSWORD_ESCAPED=$(printf '%s' "$POSTGRES_PASSWORD" | sed 's/"/\\"/g')
DOMAIN_NAME_ESCAPED=$(printf '%s' "$DOMAIN_NAME" | sed 's/"/\\"/g')
QDRANT_API_KEY_ESCAPED=$(printf '%s' "$QDRANT_API_KEY" | sed 's/"/\\"/g')
CRAWL4AI_JWT_SECRET_ESCAPED=$(printf '%s' "$CRAWL4AI_JWT_SECRET" | sed 's/"/\\"/g')
WAHA_API_USERNAME_ESCAPED=$(printf '%s' "$WAHA_API_USERNAME" | sed 's/"/\\"/g')
WAHA_API_PASSWORD_ESCAPED=$(printf '%s' "$WAHA_API_PASSWORD" | sed 's/"/\\"/g')

cat > .env << EOL
# Settings for n8n
N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY_ESCAPED"
N8N_USER_MANAGEMENT_JWT_SECRET="$N8N_USER_MANAGEMENT_JWT_SECRET_ESCAPED"
N8N_DEFAULT_USER_EMAIL="$N8N_DEFAULT_USER_EMAIL_ESCAPED"
N8N_DEFAULT_USER_PASSWORD="$N8N_PASSWORD_ESCAPED"

# n8n host configuration
SUBDOMAIN="n8n"
GENERIC_TIMEZONE="$GENERIC_TIMEZONE_ESCAPED"

# Settings for Flowise
FLOWISE_USERNAME="admin"
FLOWISE_PASSWORD="$FLOWISE_PASSWORD_ESCAPED"

# Settings for PostgreSQL
POSTGRES_DB="$POSTGRES_DB_ESCAPED"
POSTGRES_USER="$POSTGRES_USER_ESCAPED"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD_ESCAPED"

# Domain settings
DOMAIN_NAME="$DOMAIN_NAME_ESCAPED"

# --- Qdrant Settings (Optional) ---
# Uncomment the following line in this file AND in qdrant-docker-compose.yaml to enable API key
QDRANT_API_KEY="$QDRANT_API_KEY_ESCAPED"

# Secret for Crawl4AI API authentication
CRAWL4AI_JWT_SECRET="$CRAWL4AI_JWT_SECRET_ESCAPED"

# WhatsApp HTTP API credentials
WAHA_API_USERNAME="$WAHA_API_USERNAME_ESCAPED"
WAHA_API_PASSWORD="$WAHA_API_PASSWORD_ESCAPED"

# Хеш пароля для базовой аутентификации Caddy (генерируется автоматически)
WAHA_API_PASSWORD_HASH="$(caddy hash-password --plaintext $WAHA_API_PASSWORD 2>/dev/null || echo 'JDJhJDE0JDhoVFhDVHJJZWZ4ZmUwTTg5ZmRQeU9sVUtpNEZHRVd1MEh2OUxiQVV0RHVkWENuM1BHVEpL')" 
EOL

# Проверка успешности создания .env файла
if [ ! -f ".env" ]; then
  echo "ERROR: Failed to create .env file. Please check permissions and disk space in the project root directory." >&2
  exit 1
fi

echo "Secret keys generated and saved to .env file"

# Save passwords for future use - using quotes to properly handle special characters
echo "N8N_PASSWORD=\"$N8N_PASSWORD\"" > ./setup-files/passwords.txt
echo "FLOWISE_PASSWORD=\"$FLOWISE_PASSWORD\"" >> ./setup-files/passwords.txt
echo "POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\"" >> ./setup-files/passwords.txt
echo " " >> ./setup-files/passwords.txt
echo "Qdrant Vector DB is running internally." >> ./setup-files/passwords.txt
echo "  - Access from n8n/Flowise via: http://qdrant:6333" >> ./setup-files/passwords.txt
echo "  - Optional API Key (if enabled in .env & compose): $QDRANT_API_KEY" >> ./setup-files/passwords.txt
echo " " >> ./setup-files/passwords.txt
echo "Access URLs:" >> ./setup-files/passwords.txt
echo "  n8n:      https://n8n.${DOMAIN_NAME}" >> ./setup-files/passwords.txt
echo "  Flowise:  https://flowise.${DOMAIN_NAME}" >> ./setup-files/passwords.txt
echo "  Adminer:  https://adminer.${DOMAIN_NAME}" >> ./setup-files/passwords.txt
echo " " >> ./setup-files/passwords.txt
echo "Adminer Connection Details (for n8n DB):" >> ./setup-files/passwords.txt
echo "  System:   PostgreSQL" >> ./setup-files/passwords.txt
echo "  Server:   n8n_postgres (this is the Docker service name)" >> ./setup-files/passwords.txt
echo "  Username: ${POSTGRES_USER}" >> ./setup-files/passwords.txt
echo "  Password: ${POSTGRES_PASSWORD}" >> ./setup-files/passwords.txt
echo "  Database: ${POSTGRES_DB}" >> ./setup-files/passwords.txt
echo " " >> ./setup-files/passwords.txt
echo "Crawl4AI API JWT Secret:" >> ./setup-files/passwords.txt
echo "  - This secret is used for API authentication." >> ./setup-files/passwords.txt
echo "  - Stored in .env as CRAWL4AI_JWT_SECRET" >> ./setup-files/passwords.txt
echo "Qdrant API Key:" >> ./setup-files/passwords.txt
echo "  - This key is used for Qdrant API authentication." >> ./setup-files/passwords.txt
echo "  - Stored in .env as QDRANT_API_KEY" >> ./setup-files/passwords.txt
echo " " >> ./setup-files/passwords.txt
echo "WAHA API Credentials:" >> ./setup-files/passwords.txt
echo "  - Username: ${WAHA_API_USERNAME}" >> ./setup-files/passwords.txt
echo "  - Password: ${WAHA_API_PASSWORD}" >> ./setup-files/passwords.txt
echo "  - These credentials are used for WhatsApp HTTP API authentication." >> ./setup-files/passwords.txt
echo "=======================================================" >> ./setup-files/passwords.txt

echo "✅ Secret keys and passwords successfully generated"
exit 0