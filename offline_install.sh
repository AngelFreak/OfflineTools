#!/bin/bash

# offline_install.sh
# Offline installer for applications in setup_* directories, PLUS Docker images

set -e

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ Please run this script as root (use sudo)."
    exit 1
fi

# Find all directories matching setup_*
SETUP_DIRS=(setup_*)
if [ ${#SETUP_DIRS[@]} -eq 0 ]; then
    echo "❌ No 'setup_*' directories found in $(pwd)."
    exit 1
fi

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

# Process each selected directory
for DIR in "${SELECTED_DIRS[@]}"; do
    echo
    APP_NAME="${DIR#setup_}"
    echo "🚀 Processing bundle: $APP_NAME"
    
    # 1) Install any .deb files
    if compgen -G "$DIR"/*.deb > /dev/null; then
        echo "   📦 Installing .deb packages..."
        dpkg -i "$DIR"/*.deb || true
    else
        echo "   ⚠️ No .deb files found in $DIR"
    fi

    # 2) Load any Docker images
    if compgen -G "$DIR"/*.tar > /dev/null; then
        if [ "$DOCKER_AVAILABLE" = true ]; then
            echo "   🐳 Loading Docker images..."
            for TAR in "$DIR"/*.tar; do
                echo "     ↪ docker load -i $(basename "$TAR")"
                docker load -i "$TAR" || echo "     ⚠️ Failed to load $TAR"
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
apt-get install -f -y --no-download || {
    echo "⚠️ Some dependencies may be missing. Ensure all .deb files are present."
}

echo
echo "✅ All done!"
