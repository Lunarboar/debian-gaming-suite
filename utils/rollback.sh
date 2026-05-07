#!/bin/bash

BACKUP_DIR="$HOME/.local/share/debian-gaming-backups/$(date +%Y%m%d-%H%M%S)"

backup_file() {
    local FILE="$1"
    if [[ -f "$FILE" ]]; then
        mkdir -p "$BACKUP_DIR"
        local DEST="$BACKUP_DIR$(dirname "$FILE")"
        mkdir -p "$DEST"
        sudo cp "$FILE" "$DEST/$(basename "$FILE")"
        # Log the backup in a hidden file in the backup dir for restoration tracking
        echo "$FILE" | sudo tee -a "$BACKUP_DIR/file_list.txt" > /dev/null
    fi
}

create_restore_script() {
    local RESTORE_SCRIPT="$BACKUP_DIR/restore.sh"
    sudo tee "$RESTORE_SCRIPT" > /dev/null << 'EOF'
#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)"
   exit 1
fi

BASE_DIR=$(dirname "$0")
if [[ ! -f "$BASE_DIR/file_list.txt" ]]; then
    echo "No file list found in $BASE_DIR"
    exit 1
fi

while read -r original_file; do
    backup_path="$BASE_DIR$original_file"
    if [[ -f "$backup_path" ]]; then
        echo "Restoring $original_file..."
        cp "$backup_path" "$original_file"
    fi
done < "$BASE_DIR/file_list.txt"

echo "Rollback complete. Please reboot."
EOF
    sudo chmod +x "$RESTORE_SCRIPT"
}
