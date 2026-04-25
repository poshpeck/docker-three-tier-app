## Docker-three-tier-app
A production-style three-tier web application fully containerised with Docker and Docker Compose. Built as part of a hands-on DevOps learning curriculum targeting UK engineering roles.
The stack consists of an Nginx reverse proxy, a Python Flask application server, and a PostgreSQL database — all running in isolated containers on a shared internal Docker network.

```text
Architecture   
Browser / Client
       │
       │ HTTP :80 (only public port)
       ▼
┌─────────────────────────────────────────┐
│           Docker Network                │
│                                         │
│  ┌─────────────┐                        │
│  │    Nginx    │  ← Reverse proxy       │
│  │  :80 (pub)  │    SSL termination     │
│  └──────┬──────┘    Request routing     │
│         │                               │
│         │ proxy_pass :5000 (internal)   │
│         ▼                               │
│  ┌─────────────┐                        │
│  │    Flask    │  ← App server          │
│  │  app:5000   │    REST API            │
│  └──────┬──────┘    DB queries          │
│         │                               │
│         │ psycopg2 :5432 (internal)     │
│         ▼                               │
│  ┌─────────────┐    ┌──────────────┐   │
│  │  PostgreSQL │───▶│    Volume    │   │
│  │   db:5432   │    │ postgres_data│   │
│  └─────────────┘    └──────────────┘   │
└─────────────────────────────────────────┘
```

## Services

| Service | Image                 | Internal Port | Public Port | Purpose                         |
|--------|-----------------------|---------------|-------------|---------------------------------|
| nginx  | nginx:alpine          | 80            | 80          | Reverse proxy, single entry point |
| app    | custom (python:3.11-slim) | 5000         | none        | Flask REST API                  |
| db     | postgres:15-alpine    | 5432          | none        | PostgreSQL database             |



## Key design decisions
**Only Nginx is exposed publicly.** Flask and Postgres are internal-only — unreachable from outside the Docker network. This means the app server is never directly exposed to the internet.   
**Health checks before startup.** The Flask container waits for Postgres to pass a health check before starting. This prevents connection errors on cold start, which is the most common Docker Compose failure mode.   
**Named volume for persistence.** Database data is stored in a Docker-managed volume (postgres_data), not inside the container. Containers can be destroyed and recreated without data loss.  

## Project Structure
```text
docker-three-tier-app/
├── app/
│   ├── app.py              # Flask application — routes and DB logic
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Container build instructions
├── nginx/
│   └── nginx.conf          # Reverse proxy configuration
├── db/
│   └── init.sql            # Database schema and seed data
├── docker-compose.yml      # Multi-service orchestration
├── .gitignore
└── README.md
```

## Prerequisites

- Docker Engine 20.10+  
- Docker Compose plugin v2+  
- Git  

## Verify your installation:
```bash
docker --version
docker compose version
```

## Getting Started
1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/docker-three-tier-app.git
cd docker-three-tier-app
```
2. Build and start the stack
bashdocker compose up --build
On first run, Docker will:

    - Pull postgres:15-alpine and nginx:alpine from Docker Hub
    - Build the Flask image from app/Dockerfile
    - Create an internal network for the three containers
    - Start Postgres and run the health check
    - Start Flask once Postgres is healthy
    - Start Nginx and begin accepting traffic on port 80

3. Verify all services are running
```bash
docker compose ps
```
Expected output:
```text
NAME                    STATUS          PORTS
docker-app-db-1         running (healthy)
docker-app-app-1        running
docker-app-nginx-1      running         0.0.0.0:80->80/tcp
```

4. Test the endpoints
```bash
# Root endpoint
curl http://localhost

# Database health check
curl http://localhost/health

# Fetch all users
curl http://localhost/users
```

## API Reference  
```
GET /
```
Returns application status.  
### Response:
```json
json{
  "status": "ok",
  "message": "App is running"
}
```

```
GET /health
```

Checks application and database connectivity. Used by monitoring tools and load balancers.  
### Response (healthy):
```json
json{
  "status": "healthy",
  "db": "connected"
}
```
### Response (unhealthy):
```json
json{
  "status": "unhealthy",
  "db": "connection refused"
}
```
HTTP status code is `200` when healthy, `500` when unhealthy.

`GET /users`  
Returns all users from the database.  
Response:
```json
json[
  { "id": 1, "name": "Paul Smith", "email": "paul@example.com" },
  { "id": 2, "name": "Jane Doe", "email": "jane@example.com" },
  { "id": 3, "name": "Bob Jones", "email": "bob@example.com" }
]
```
## Configuration
Environment variables are defined in `docker-compose.yml` under each service. For production use, move these to a `.env` file and never commit it to version control.

## Environment Variables

| Variable       | Default       | Description                                      |
|---------------|---------------|--------------------------------------------------|
| `DB_HOST`     | `db`          | PostgreSQL hostname (Docker service name)        |
| `DB_NAME`     | `appdb`       | Database name                                   |
| `DB_USER`     | `appuser`     | Database user                                   |
| `DB_PASSWORD` | `apppassword` | Database password — change in production        |

### Using a .env file  
Create a `.env` file in the project root:
```env
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=your_secure_password_here
```
Update `docker-compose.yml` to reference it:
```yaml
env_file:
  - .env
```
The `.env` file is already listed in .gitignore — never commit credentials to Git.

## Common Commands  
### Stack management
```bash
# Start in foreground (see all logs)
docker compose up --build

# Start in background
docker compose up -d --build

# Stop containers (data preserved)
docker compose down

# Stop containers and delete volumes (data wiped)
docker compose down -v

# Rebuild a single service without restarting others
docker compose up -d --build app
```
### Debugging
```bash
# Follow live logs for all services
docker compose logs -f

# Follow logs for one service only
docker compose logs -f app

# Open a shell inside the Flask container
docker compose exec app bash

# Connect to PostgreSQL directly
docker compose exec db psql -U appuser -d appdb

# Run a raw SQL query
docker compose exec db psql -U appuser -d appdb -c "SELECT * FROM users;"

# Monitor container resource usage
docker stats
```
### Inspecting the network
``` bash
# List Docker networks
docker network ls
# Inspect the internal network (shows container IPs and DNS)
docker network inspect docker-app_default
```
## How the Nginx Reverse Proxy Works
Nginx is the only container with a publicly exposed port. All traffic enters on port 80, and Nginx forwards it internally to Flask on port 5000 using Docker's internal DNS.
```nginx
upstream flask_app {
    server app:5000;   # "app" resolves via Docker DNS
}

location / {
    proxy_pass http://flask_app;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```
The `X-Real-IP` and `X-Forwarded-For` headers preserve the original client IP address, which would otherwise be lost when Nginx forwards the request.  
To add `HTTPS` in production, terminate SSL at Nginx by adding a certificate and a `listen 443 ssl` block. Flask requires no changes.

## Database
### Schema
```sql
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(100) UNIQUE NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);
```
## Seed data
Three users are inserted automatically on first startup via `db/init.sql.` Postgres runs all `.sql` files placed in `/docker-entrypoint-initdb.d/` on initialisation.  
## Data persistence
Database data is stored in a Docker named volume (`postgres_data`) mounted at `/var/lib/postgresql/data` inside the Postgres container. The volume persists independently of the container lifecycle:
```bash
# Container destroyed — data survives
docker compose down

# Volume destroyed — data wiped
docker compose down -v
```
In production, back up the volume or use a managed database service (Azure Database for PostgreSQL, AWS RDS) instead of a containerised database.  

## Dockerfile Breakdown
```docker
fileFROM python:3.11-slim        # Small official base image

WORKDIR /app                 # All commands run from here

COPY requirements.txt .      # Copy deps file first — layer cache optimisation
RUN pip install --no-cache-dir -r requirements.txt

COPY . .                     # Copy app code after deps (cache not invalidated by code changes)

EXPOSE 5000                  # Documents the port — does not publish it

CMD ["python", "app.py"]     # Exec form handles OS signals correctly
```
Layer caching is the reason `requirements.txt` is copied and installed before the application code. Docker caches each layer. If only `app.py` changes, Docker reuses the cached pip install layer and rebuilds in seconds rather than minutes.  




### Skills Demonstrated

    - Docker image authoring with multi-layer caching optimisation
    - Multi-service orchestration with Docker Compose
    - Container networking and internal DNS resolution
    - Nginx reverse proxy configuration with header forwarding
    - PostgreSQL containerisation with health checks and volume persistence
    - Defensive startup ordering with depends_on conditions
    - Database initialisation via entrypoint scripts


### License
 MIT
