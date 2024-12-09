# Backend Template

Modern backend template with Docker, monitoring, and security best practices.

## Requirements

### Production
- Docker and Docker Compose
- Caddy server

### Development
- Docker and Docker Compose

## Production Server Setup

### Initial Server Setup

1. Install Docker:
```bash
# Remove old versions
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    sudo apt-get remove $pkg
done

# Install Docker
sudo apt-get update
sudo apt-get install -y curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install packages
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker
sudo groupadd docker
sudo usermod -aG docker $USER
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

2. Configure SSH and Firewall:
```bash
# SSH Configuration
sudo sed -i 's/#Port 22/Port 5000/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# UFW Configuration
sudo ufw logging on
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw enable
```

### Environment Setup

1. Clone repository and setup environment variables:
```bash
# Copy configuration examples
cp env.example/* env/
```

2. Required .env files:
- `application.env`: Main application settings
- `database.env`: PostgreSQL settings
- `directus.env`: Directus CMS settings
- `smtp.env`: Email settings
- `netdata.env`: Monitoring settings

## Development

### Database Operations

#### Migrations
The migration system uses two main scripts:
- `create-migration-folder.sh`: Creates new migration folder with timestamp
- `apply-migration.sh`: Applies migration to database
- `run-all-migrations.sh`: Runs all pending migrations

## Deployment

### Application Launch
```bash
# Start all services
docker compose -f docker-compose.prod.yml up -d

# Set Directus permissions
docker exec -u root backend_directus_1 chown -R node:node /directus/extensions /directus/uploads
```

### Monitoring
Monitoring is implemented through Netdata with:
- System metrics
- Docker container monitoring
- Custom metrics
- Alert system

Access dashboard at `https://your-domain:19999`

## Services

### Main Components
- Directus (port 8055): Headless CMS
- PostgreSQL (port 5432): Main database
- Redis: Caching service
- Netdata (port 19999): Monitoring

### Service Configuration
All services are configured through Docker Compose files:
- `docker-compose.yml`: Base configuration
- `docker-compose.prod.yml`: Production overrides
- `services/docker-compose.netdata.yml`: Monitoring setup

## Security

- All external ports closed except 80/443 (Caddy) and 5000 (SSH)
- Automatic SSL through Caddy
- Password authentication disabled for SSH
- UFW firewall enabled
- Rate limiting on API endpoints
- Security headers enabled

## License

This template is available under the MIT License.