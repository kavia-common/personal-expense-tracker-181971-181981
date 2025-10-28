# Expense Tracker Database (PostgreSQL)

This container provisions a local PostgreSQL instance for the Personal Expense Tracker app.

Key defaults (can be overridden via environment variables):
- POSTGRES_HOST: localhost
- POSTGRES_PORT: 5001
- POSTGRES_USER: appuser
- POSTGRES_PASSWORD: dbuser123
- POSTGRES_DB: myapp
- POSTGRES_URL: postgresql://appuser:dbuser123@localhost:5001/myapp

Startup
- Run ./startup.sh to initialize and start PostgreSQL.
- The script will:
  - Initialize data dir if needed
  - Start PostgreSQL on port 5001 (unless overridden via DB_PORT or POSTGRES_PORT)
  - Create the database and user if missing
  - Grant necessary permissions
  - Generate helper files

Helper files generated
- db_connection.txt: One-line psql command using POSTGRES_URL
- db_visualizer/postgres.env: export-ready environment variables
- postgres.env: plain key=value pairs

Overriding configuration
- You can override via env vars before running:
  - DB_NAME, DB_USER, DB_PASSWORD, DB_PORT
  - or directly: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_PORT, POSTGRES_HOST
- POSTGRES_URL will be auto-derived if not provided.

Connection examples
- psql -h localhost -U appuser -d myapp -p 5001
- psql postgresql://appuser:dbuser123@localhost:5001/myapp
