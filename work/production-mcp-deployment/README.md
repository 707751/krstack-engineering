# Production MCP Deployment

A practical production deployment workflow for a Python-based MCP application using Linux, Git, SSH, Bash, Rsync, Docker Compose, and Nginx.

This project demonstrates how application source can be safely pulled from Git, promoted to a production directory, containerized, and exposed through Nginx over HTTPS.

> This is a sanitized reference implementation. Replace example paths, usernames, domains, and application commands with values appropriate for your environment.

## Architecture

```text
Developer
    |
    v
Git Repository
    |
    | SSH
    v
Linux Server
    |
    +-- /srv/apps/mcp-platform/source/
    |        |
    |        +-- Git-managed source
    |
    +-- /opt/deployment/mcp-platform/
    |        |
    |        +-- Git pull script
    |        +-- Rsync deployment script
    |        +-- Backup file list
    |        +-- Rsync exclude list
    |        +-- Deployment logs
    |
    +-- /srv/apps/mcp-platform/production/
             |
             v
        Docker Compose
        +-- Web
        +-- Admin
        +-- Scheduler
             |
             v
           Nginx
             |
             v
           HTTPS
```

## Repository Contents

```text
production-mcp-deployment/
├── README.md
├── scripts/
│   ├── git-pull-mcp-platform.sh
│   └── rsync-mcp-platform.sh
├── config/
│   ├── backup-files.list.example
│   └── rsync-exclude.txt
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── nginx/
│   └── mcp.example.conf
└── images/
```

## Example Server Paths

```text
Application source:
/srv/apps/mcp-platform/source/

Production application:
/srv/apps/mcp-platform/production/

Deployment scripts:
/opt/deployment/mcp-platform/

Application backups:
/srv/apps/mcp-platform/backup/
```

## 1. Create Deployment User

```bash
sudo useradd --create-home --shell /bin/bash deploysvc
```

## 2. Prepare Directories

```bash
sudo mkdir -p /srv/apps/mcp-platform/source
sudo mkdir -p /srv/apps/mcp-platform/production
sudo mkdir -p /srv/apps/mcp-platform/backup
sudo mkdir -p /opt/deployment/mcp-platform
```

Set ownership:

```bash
sudo chown -R deploysvc:deploysvc /srv/apps/mcp-platform
sudo chown -R deploysvc:deploysvc /opt/deployment/mcp-platform
```

## 3. Git / SSH Access

Generate an SSH key for the deployment user:

```bash
sudo -iu deploysvc

ssh-keygen -t ed25519
```

Add the public key to your Git provider and test authentication.

Example:

```bash
ssh -T git@bitbucket.org
```

Clone the application into:

```text
/srv/apps/mcp-platform/source/
```

## 4. Install Deployment Scripts

Copy:

```text
scripts/git-pull-mcp-platform.sh
scripts/rsync-mcp-platform.sh
```

to:

```text
/opt/deployment/mcp-platform/
```

Make them executable:

```bash
chmod +x /opt/deployment/mcp-platform/*.sh
```

Also copy:

```text
config/backup-files.list.example
config/rsync-exclude.txt
```

Example:

```bash
cp config/backup-files.list.example \
   /opt/deployment/mcp-platform/backup-files.list

cp config/rsync-exclude.txt \
   /opt/deployment/mcp-platform/rsync-exclude.txt
```

## 5. Safe Git Update

Run:

```bash
/opt/deployment/mcp-platform/git-pull-mcp-platform.sh
```

The script performs:

```text
Backup protected runtime files
        |
        v
Git stash
        |
        v
Pull latest code
        |
        v
Restore protected files
        |
        v
Record deployment log
```

Files such as `.env`, `instance`, and `data` can be protected using `backup-files.list`.

## 6. Promote Source to Production

Run:

```bash
/opt/deployment/mcp-platform/rsync-mcp-platform.sh
```

The script:

- synchronizes source to production using Rsync
- applies exclusion rules
- records changed files
- creates date-based backups
- writes deployment logs

## 7. Docker

Example Docker configuration is available under:

```text
docker/
```

Deploy it with your application and start the services:

```bash
docker compose up -d --build
```

Example workloads:

```text
Web application
Admin application
Background scheduler
```

Check:

```bash
docker compose ps
```

## 8. Nginx

Example configuration:

```text
nginx/mcp.example.conf
```

Example request flow:

```text
https://mcp.example.com/
        |
        +---- /admin ----> 127.0.0.1:8010
        |
        +---- / ---------> 127.0.0.1:8001
```

Install the configuration according to your Linux distribution and validate it:

```bash
sudo nginx -t
```

Then reload Nginx:

```bash
sudo systemctl reload nginx
```

## Deployment Flow

```text
Git Repository
      |
      v
Safe Git Pull
      |
      v
Source Directory
      |
      v
Rsync Promotion
      |
      v
Production Directory
      |
      v
Docker Compose
      |
      v
Nginx
      |
      v
HTTPS
```

## Security

Do not store production secrets in this repository.

Keep the following outside Git:

```text
.env
SSH private keys
API tokens
Passwords
Production certificates
Internal credentials
```

The examples in this repository use sanitized domains, usernames, paths, and service names.

## Technologies

`Linux` `Git` `SSH` `Bash` `Rsync` `Python` `Docker` `Docker Compose` `Nginx` `HTTPS/TLS`

---

Part of **KRSTACK Engineering** — practical production infrastructure, automation, and troubleshooting.
