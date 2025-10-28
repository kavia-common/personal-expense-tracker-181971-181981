#!/bin/bash

# Minimal PostgreSQL startup script with full paths and standardized env handling
# Defaults with override from environment; DB_PORT defaults to 5001 if not provided
DB_NAME="${DB_NAME:-myapp}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-dbuser123}"
DB_PORT="${DB_PORT:-5001}"

# Derived/standard env exports for downstream usage
export POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
export POSTGRES_PORT="${POSTGRES_PORT:-${DB_PORT}}"
export POSTGRES_USER="${POSTGRES_USER:-${DB_USER}}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD}}"
export POSTGRES_DB="${POSTGRES_DB:-${DB_NAME}}"
export POSTGRES_URL="${POSTGRES_URL:-postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}}"

echo "Starting PostgreSQL setup..."
echo "Config -> DB: ${POSTGRES_DB} | USER: ${POSTGRES_USER} | PORT: ${POSTGRES_PORT}"

# Find PostgreSQL version and set paths
PG_VERSION=$(ls /usr/lib/postgresql/ | head -1)
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

echo "Found PostgreSQL version: ${PG_VERSION}"

# Check if PostgreSQL is already running on the specified port
if sudo -u postgres ${PG_BIN}/pg_isready -p ${POSTGRES_PORT} > /dev/null 2>&1; then
    echo "PostgreSQL is already running on port ${POSTGRES_PORT}!"
    echo "Database: ${POSTGRES_DB}"
    echo "User: ${POSTGRES_USER}"
    echo "Port: ${POSTGRES_PORT}"
    echo ""
    echo "To connect to the database, use:"
    echo "psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -p ${POSTGRES_PORT}"
    
    # Ensure helper files reflect current config
    echo "psql ${POSTGRES_URL}" > db_connection.txt
    mkdir -p db_visualizer
    cat > db_visualizer/postgres.env << EOF
export POSTGRES_URL="${POSTGRES_URL}"
export POSTGRES_USER="${POSTGRES_USER}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export POSTGRES_DB="${POSTGRES_DB}"
export POSTGRES_PORT="${POSTGRES_PORT}"
export POSTGRES_HOST="${POSTGRES_HOST}"
EOF
    echo "Updated helper files (db_connection.txt, db_visualizer/postgres.env)"
    echo ""
    echo "Script stopped - server already running."
    exit 0
fi

# Also check if there's a PostgreSQL process running (in case pg_isready fails)
if pgrep -f "postgres.*-p ${POSTGRES_PORT}" > /dev/null 2>&1; then
    echo "Found existing PostgreSQL process on port ${POSTGRES_PORT}"
    echo "Attempting to verify connection..."
    
    # Try to connect and verify the database exists
    if sudo -u postgres ${PG_BIN}/psql -p ${POSTGRES_PORT} -d ${POSTGRES_DB} -c '\q' 2>/dev/null; then
        echo "Database ${POSTGRES_DB} is accessible."
        # Ensure helper files reflect current config
        echo "psql ${POSTGRES_URL}" > db_connection.txt
        mkdir -p db_visualizer
        cat > db_visualizer/postgres.env << EOF
export POSTGRES_URL="${POSTGRES_URL}"
export POSTGRES_USER="${POSTGRES_USER}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export POSTGRES_DB="${POSTGRES_DB}"
export POSTGRES_PORT="${POSTGRES_PORT}"
export POSTGRES_HOST="${POSTGRES_HOST}"
EOF
        echo "Updated helper files (db_connection.txt, db_visualizer/postgres.env)"
        echo "Script stopped - server already running."
        exit 0
    fi
fi

# Initialize PostgreSQL data directory if it doesn't exist
if [ ! -f "/var/lib/postgresql/data/PG_VERSION" ]; then
    echo "Initializing PostgreSQL..."
    sudo -u postgres ${PG_BIN}/initdb -D /var/lib/postgresql/data
fi

# Start PostgreSQL server in background
echo "Starting PostgreSQL server..."
sudo -u postgres ${PG_BIN}/postgres -D /var/lib/postgresql/data -p ${POSTGRES_PORT} &

# Wait for PostgreSQL to start
echo "Waiting for PostgreSQL to start..."
sleep 5

# Check if PostgreSQL is running
for i in {1..15}; do
    if sudo -u postgres ${PG_BIN}/pg_isready -p ${POSTGRES_PORT} > /dev/null 2>&1; then
        echo "PostgreSQL is ready!"
        break
    fi
    echo "Waiting... ($i/15)"
    sleep 2
done

# Create database and user (idempotent)
echo "Setting up database and user..."
# Create DB if not exists
sudo -u postgres ${PG_BIN}/psql -p ${POSTGRES_PORT} -d postgres -v ON_ERROR_STOP=1 << EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${POSTGRES_DB}') THEN
      PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE ${POSTGRES_DB}');
   END IF;
END
\$\$ LANGUAGE plpgsql;
EOF

# Fallback if dblink not available, try createdb (ignore if exists)
sudo -u postgres ${PG_BIN}/createdb -p ${POSTGRES_PORT} ${POSTGRES_DB} 2>/dev/null || echo "Database might already exist"

# Ensure user exists and grant permissions
sudo -u postgres ${PG_BIN}/psql -p ${POSTGRES_PORT} -d postgres << EOF
-- Create user if doesn't exist
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
        CREATE ROLE ${POSTGRES_USER} WITH LOGIN PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
    ALTER ROLE ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
END
\$\$;

-- Grant database-level permissions
GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};

-- Connect to the specific database for schema-level permissions
\\c ${POSTGRES_DB}

-- Ensure permissions on public schema
GRANT USAGE ON SCHEMA public TO ${POSTGRES_USER};
GRANT CREATE ON SCHEMA public TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${POSTGRES_USER};
GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${POSTGRES_USER};
EOF

# Save connection command to a file
echo "psql ${POSTGRES_URL}" > db_connection.txt
echo "Connection string saved to db_connection.txt"

# Save environment variables to a file
mkdir -p db_visualizer
cat > db_visualizer/postgres.env << EOF
export POSTGRES_URL="${POSTGRES_URL}"
export POSTGRES_USER="${POSTGRES_USER}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export POSTGRES_DB="${POSTGRES_DB}"
export POSTGRES_PORT="${POSTGRES_PORT}"
export POSTGRES_HOST="${POSTGRES_HOST}"
EOF

# Additionally, provide top-level postgres.env for convenience
cat > postgres.env << EOF
POSTGRES_URL="${POSTGRES_URL}"
POSTGRES_USER="${POSTGRES_USER}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
POSTGRES_DB="${POSTGRES_DB}"
POSTGRES_PORT="${POSTGRES_PORT}"
POSTGRES_HOST="${POSTGRES_HOST}"
EOF

echo "PostgreSQL setup complete!"
echo "Database: ${POSTGRES_DB}"
echo "User: ${POSTGRES_USER}"
echo "Port: ${POSTGRES_PORT}"
echo ""

echo "Environment variables saved to:"
echo " - db_visualizer/postgres.env (export-prefixed)"
echo " - postgres.env (plain key=value)"
echo "To use with Node.js viewer, run: source db_visualizer/postgres.env"

echo "To connect to the database, use one of the following commands:"
echo "psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -p ${POSTGRES_PORT}"
echo "$(cat db_connection.txt)"
