# Bitwarden Backup Service Setup Guide

## Overview
This guide will help you set up the Bitwarden backup script to run automatically as a user service on login.

## Files Created
- **Script**: `bitwarden_backup.sh` - The main backup script
- **Service**: `bitwarden-backup.service` - Systemd user service file
- **Log**: `~/.bitwarden_backup.log` - Hidden log file for service output

## Setup Instructions

### 1. Save the Script
```bash
# Save the script to your home directory
sudo nano /home/luis/bitwarden_backup.sh

# Make it executable
chmod +x /home/luis/bitwarden_backup.sh
```

### 2. Configure Environment Variables
Edit the service file to include your actual credentials:

```bash
# Edit the service file
nano ~/.config/systemd/user/bitwarden-backup.service
```

Replace the placeholder values:
- `your_client_id_here` → Your actual Bitwarden Client ID
- `your_client_secret_here` → Your actual Bitwarden Client Secret
- `your_master_password_here` → Your actual Bitwarden master password

### 3. Install the Service

```bash
# Create the systemd user directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Copy the service file
cp bitwarden-backup.service ~/.config/systemd/user/

# Reload systemd user daemon
systemctl --user daemon-reload

# Enable the service to run on login
systemctl --user enable bitwarden-backup.service
```

### 4. Test the Service

```bash
# Test run the service
systemctl --user start bitwarden-backup.service

# Check the status
systemctl --user status bitwarden-backup.service

# View the log
tail -f ~/.bitwarden_backup.log
```

### 5. Enable Lingering (Optional)
If you want the service to run even when you're not logged in:

```bash
sudo loginctl enable-linger luis
```

## Security Considerations

### Protecting Your Credentials
The service file contains sensitive credentials. Secure it:

```bash
# Set strict permissions on the service file
chmod 600 ~/.config/systemd/user/bitwarden-backup.service

# Verify permissions
ls -la ~/.config/systemd/user/bitwarden-backup.service
```

### Alternative: Environment File
For better security, you can use an environment file:

1. Create a secure environment file:
```bash
# Create environment file
cat > ~/.bitwarden_env << 'EOF'
BW_CLIENT_ID=your_client_id_here
BW_CLIENT_SECRET=your_client_secret_here
BW_MASTER_PASSWORD=your_master_password_here
EOF

# Secure it
chmod 600 ~/.bitwarden_env
```

2. Modify the service file to use it:
```ini
[Service]
Type=oneshot
ExecStart=/home/luis/bitwarden_backup.sh
EnvironmentFile=/home/luis/.bitwarden_env
WorkingDirectory=/home/luis
User=luis
StandardOutput=append:/home/luis/.bitwarden_backup.log
StandardError=append:/home/luis/.bitwarden_backup.log
```

## Monitoring

### Check Service Status
```bash
# Service status
systemctl --user status bitwarden-backup.service

# View recent logs
tail -20 ~/.bitwarden_backup.log

# Follow logs in real-time
tail -f ~/.bitwarden_backup.log
```

### Schedule Regular Backups
To run backups on a schedule instead of just on login, create a timer:

```bash
# Create timer file
cat > ~/.config/systemd/user/bitwarden-backup.timer << 'EOF'
[Unit]
Description=Run Bitwarden Backup Daily
Requires=bitwarden-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable the timer
systemctl --user enable bitwarden-backup.timer
systemctl --user start bitwarden-backup.timer
```

## Troubleshooting

### Common Issues
1. **Permission denied**: Check file permissions and ownership
2. **Service fails**: Check `systemctl --user status bitwarden-backup.service`
3. **Wrong credentials**: Verify environment variables in service file
4. **Path issues**: Ensure all paths are absolute in the service file

### Log Analysis
The log file contains detailed information about each backup attempt:
```bash
# Search for errors
grep ERROR ~/.bitwarden_backup.log

# View today's backups
grep "$(date +%Y-%m-%d)" ~/.bitwarden_backup.log
```

## Maintenance

### Log Rotation
The script automatically rotates logs when they exceed 10MB. Old logs are saved as `.bitwarden_backup.log.old`.

### Service Updates
After modifying the script or service file:
```bash
systemctl --user daemon-reload
systemctl --user restart bitwarden-backup.service
```