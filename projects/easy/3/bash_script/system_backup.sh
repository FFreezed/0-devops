#!/bin/bash

VAULT_DIR="/var/backups/web_backup"

if [ ! -d "$VAULT_DIR" ]; then
    echo "Creating backup directory: $VAULT_DIR"
    sudo mkdir -p "$VAULT_DIR"
fi

BACKUP_FILE="$VAULT_DIR/web-backup-$(date +%Y-%m-%d).tar.gz"

echo "Archiving web content to $BACKUP_FILE"
sudo tar -czf "$BACKUP_FILE" /var/www/html/

echo "Backup completed!"