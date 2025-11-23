#!/bin/bash

# offline_install.sh
# Offline installer for applications in setup_* directories, PLUS Docker images
# Version: 1.1.0

set -euo pipefail

# Show help
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    echo "Usage: sudo $(basename "$0")"
    echo "  Installs .deb packages and loads Docker images from setup_* directories"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "The script will:"
    echo "  1) Scan for setup_* directories in the current folder"
    echo "  2) Present a menu to select which bundles to install"
    echo "  3) Install .deb packages and load Docker images"
    exit 0
fi

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ Please run this script as root (use sudo)."
    exit 1
fi

# Enable nullglob so glob returns empty array if no matches
shopt -s nullglob

# Find all directories matching setup_*
SETUP_DIRS=(setup_*/)

# Restore default glob behavior
shopt -u nullglob

# Check if any directories were found
if [[ ${#SETUP_DIRS[@]} -eq 0 ]]; then
    echo "❌ No 'setup_*' directories found in $(pwd)."
    exit 1
fi

# Remove trailing slashes from directory names
SETUP_DIRS=("${SETUP_DIRS[@]%/}")

# Display the selection menu
echo "📦 Available setup bundles to install/load:"
INDEX=1
for DIR in "${SETUP_DIRS[@]}"; do
    APP_NAME="${DIR#setup_}"
    echo "  $INDEX) $APP_NAME"
    ((INDEX++))
done

echo "  a) Install/Load ALL bundles"
echo

read -p "👉 Enter numbers to process (e.g. 1 2), or 'a' for all: " -a CHOICES

# Collect selected folders
SELECTED_DIRS=()
if [[ "${CHOICES[0]}" == "a" ]]; then
    SELECTED_DIRS=("${SETUP_DIRS[@]}")
else
    for CHOICE in "${CHOICES[@]}"; do
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#SETUP_DIRS[@]} )); then
            SELECTED_DIRS+=("${SETUP_DIRS[CHOICE-1]}")
        else
            echo "⚠️ Invalid selection: $CHOICE"
        fi
    done
fi

if [ ${#SELECTED_DIRS[@]} -eq 0 ]; then
    echo "❌ No valid bundles selected. Aborting."
    exit 1
fi

# Check for Docker CLI once
if command -v docker >/dev/null 2>&1; then
    DOCKER_AVAILABLE=true
else
    DOCKER_AVAILABLE=false
fi

# Track installation results
INSTALL_ERRORS=0

# Process each selected directory
for DIR in "${SELECTED_DIRS[@]}"; do
    echo
    APP_NAME="${DIR#setup_}"
    echo "🚀 Processing bundle: $APP_NAME"

    # Verify directory exists
    if [[ ! -d "$DIR" ]]; then
        echo "   ❌ Directory not found: $DIR"
        ((INSTALL_ERRORS++)) || true
        continue
    fi

    # 1) Install any .deb files
    if compgen -G "$DIR"/*.deb > /dev/null; then
        echo "   📦 Installing .deb packages..."
        if dpkg -i "$DIR"/*.deb; then
            echo "   ✓ .deb packages installed successfully"
        else
            echo "   ⚠️ Some .deb packages failed to install (dependencies may be resolved later)"
            ((INSTALL_ERRORS++)) || true
        fi
    else
        echo "   ℹ️ No .deb files found in $DIR"
    fi

    # 2) Load any Docker images
    if compgen -G "$DIR"/*.tar > /dev/null; then
        if [ "$DOCKER_AVAILABLE" = true ]; then
            echo "   🐳 Loading Docker images..."
            for TAR in "$DIR"/*.tar; do
                echo "     ↪ docker load -i $(basename "$TAR")"
                if docker load -i "$TAR"; then
                    echo "     ✓ Loaded successfully"
                else
                    echo "     ❌ Failed to load $TAR"
                    ((INSTALL_ERRORS++)) || true
                fi
            done
        else
            echo "   ⚠️ Docker CLI not found—skipping Docker images in $DIR"
        fi
    else
        echo "   ℹ️ No Docker image archives (.tar) in $DIR"
    fi
done

# Fix dependencies (offline-safe)
echo
echo "🔧 Fixing package dependencies (offline-safe)..."
if apt-get install -f -y --no-download; then
    echo "✓ Dependencies resolved successfully"
else
    echo "⚠️ Some dependencies may be missing. Ensure all .deb files are present."
    ((INSTALL_ERRORS++)) || true
fi

echo
if [[ $INSTALL_ERRORS -eq 0 ]]; then
    echo "✅ All done! Installation completed successfully."
else
    echo "⚠️ Completed with $INSTALL_ERRORS error(s). Review messages above for details."
fi
