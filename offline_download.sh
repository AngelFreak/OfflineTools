#!/bin/bash

# offline_download.sh
# 🚀 Offline downloader for .deb packages OR Docker images (with virtual-package & URI fallback)

set -e

# Record real user (for chown)
ORIG_UID=$(id -u)
ORIG_GID=$(id -g)

# 1) Where is this script? (USB mount)
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# 2) Verify required tools
echo "🔧 Checking for apt-rdepends…"
if ! command -v apt-rdepends &>/dev/null; then
  echo "❌ apt-rdepends not found. Install it with:"
  echo "   sudo apt-get update && sudo apt-get install apt-rdepends"
  exit 1
fi
# We’ll need wget for URI fallback
if ! command -v wget &>/dev/null; then
  echo "⚠️  wget not found. URI fallback will be unavailable."
fi

# 3) Choose what to download
echo
echo "📥 What would you like to download?"
echo "   1) .deb packages only"
echo "   2) Docker images only"
read -p "👉 Enter choice [1-2]: " choice
case "$choice" in
  1) WANT_DEB=true;  WANT_DOCKER=false ;;
  2) WANT_DEB=false; WANT_DOCKER=true  ;;
  *) echo "❌ Invalid choice: $choice"; exit 1 ;;
esac

# 4) Prepare a single temp folder
echo
echo "📂 Creating temporary download folder…"
LOCAL_FOLDER="$(mktemp -d -t offline_dl_XXXXXXXX)"
echo "   → $LOCAL_FOLDER"
cd "$LOCAL_FOLDER"

# 5) .deb logic
if [ "$WANT_DEB" = true ]; then
  echo
  echo "📦 Package Downloader"
  read -p "👉 Enter package names (space- or comma-separated): " pkg_in
  [[ -n "$pkg_in" ]] || { echo "❌ No packages entered. Exiting."; exit 1; }
  PACKAGES=( $(echo "$pkg_in" | tr ',' ' ' | xargs) )

  echo
  echo "🔄 Updating apt cache…"
  sudo apt-get update

  echo
  echo "🔍 Resolving dependencies…"
  deps=$(apt-rdepends "${PACKAGES[@]}" 2>/dev/null \
         | grep -Ev '^\s|^<|^PreDepends:' \
         | sort -u)
  ALL_DEBS=( "${PACKAGES[@]}" $deps )

  echo
  echo "📋 Will attempt to download these packages:"
  for p in "${ALL_DEBS[@]}"; do echo "   • $p"; done

  read -p "❓ Proceed? [y/N] " yn
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then
    echo "🚫 .deb download cancelled."
    rm -rf "$LOCAL_FOLDER"
    exit 0
  fi

  echo
  echo "⬇️  Downloading .deb packages…"
  for p in "${ALL_DEBS[@]}"; do
    # 1) Candidate check
    CANDIDATE=$(apt-cache policy "$p" | awk '/Candidate:/ {print $2}')
    if [[ "$CANDIDATE" == "(none)" || -z "$CANDIDATE" ]]; then
      echo "⚠️  '$p' is virtual. Looking for provider…"
      PROVIDER=$(apt-cache showpkg "$p" 2>/dev/null \
        | awk '/Reverse Provides:/,/^$/' \
        | tail -n +2 \
        | head -n1 \
        | cut -d' ' -f1)
      if [[ -n "$PROVIDER" ]]; then
        echo "   ↪ using provider: $PROVIDER"
        REAL_PKG="$PROVIDER"
      else
        echo "   ❌ no provider found for '$p', skipping."
        continue
      fi
    else
      REAL_PKG="$p"
    fi

    # 2) Try apt-get download
    echo "   • Downloading $REAL_PKG (for original: $p)"
    if ! apt-get download "$REAL_PKG"; then
      echo "     ⚠️ apt-get download failed for $REAL_PKG"
      # 3) Fallback: fetch URIs and wget them
      if command -v wget &>/dev/null; then
        echo "     ↪ Falling back to fetching .deb via URIs"
        URIS=$(apt-get --print-uris -qq install "$REAL_PKG" \
               | grep ^\' | cut -d\' -f2)
        if [[ -n "$URIS" ]]; then
          for uri in $URIS; do
            echo "       → wget $uri"
            wget -q "$uri" || echo "         ❌ wget failed for $uri"
          done
        else
          echo "       ❌ No URIs found for $REAL_PKG, skipping."
        fi
      else
        echo "     ❌ No wget available for URI fallback; skipping."
      fi
    fi
  done
fi

# 6) Docker logic
if [ "$WANT_DOCKER" = true ]; then
  echo
  if ! command -v docker &>/dev/null; then
    echo "⚠️  Docker CLI not found—exiting."
    rm -rf "$LOCAL_FOLDER"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    DOCKER_CMD="sudo docker"
    echo "🔐 Will use sudo for Docker commands."
  else
    DOCKER_CMD="docker"
  fi

  echo
  echo "🐳 Docker Image Downloader"
  read -p "👉 Enter Docker image names (space- or comma-separated): " img_in
  [[ -n "$img_in" ]] || { echo "❌ No images entered. Exiting."; rm -rf "$LOCAL_FOLDER"; exit 1; }
  IMAGES=( $(echo "$img_in" | tr ',' ' ' | xargs) )

  echo
  echo "⬇️  Pulling Docker images…"
  for img in "${IMAGES[@]}"; do
    echo "   • $img"
    $DOCKER_CMD pull "$img" \
      || { echo "     ❌ Failed to pull $img"; exit 1; }
  done

  SAFE_IMG=$(printf "%s_" "${IMAGES[@]}" | tr '/: ' '_' | sed 's/_$//')
  TAR_FILE="docker_images_${SAFE_IMG}.tar"

  echo
  echo "📦 Saving all images into: $TAR_FILE"
  $DOCKER_CMD save --output "$LOCAL_FOLDER/$TAR_FILE" "${IMAGES[@]}" \
    || { echo "❌ Failed to save images"; exit 1; }

  echo "🔄 Restoring ownership on $TAR_FILE"
  sudo chown "$ORIG_UID:$ORIG_GID" "$LOCAL_FOLDER/$TAR_FILE"
fi

# 7) Build destination folder name
if [ "$WANT_DEB" = true ]; then
  SAFE_DEB=$(printf "%s_" "${PACKAGES[@]}" | tr -cd '[:alnum:]_' ); SAFE_DEB=${SAFE_DEB%_}
fi
if [ "$WANT_DOCKER" = true ]; then
  SAFE_IMG=$(printf "%s_" "${IMAGES[@]}" | tr -cd '[:alnum:]_' );   SAFE_IMG=${SAFE_IMG%_}
fi

if [ -n "$SAFE_DEB" ]; then
  DIR_NAME="setup_${SAFE_DEB}"
elif [ -n "$SAFE_IMG" ]; then
  DIR_NAME="setup_docker_${SAFE_IMG}"
else
  echo "❌ Nothing to move. Exiting."
  rm -rf "$LOCAL_FOLDER"
  exit 1
fi

DEST="$SCRIPT_DIR/$DIR_NAME"

# 8) Move downloads to USB
echo
echo "📂 Moving downloads to: $DEST"
mkdir -p "$DEST"
mv "$LOCAL_FOLDER"/*.deb "$DEST/" 2>/dev/null || true
mv "$LOCAL_FOLDER"/*.tar "$DEST/" 2>/dev/null || true

# 9) Cleanup
rm -rf "$LOCAL_FOLDER"

echo
echo "✅ Download complete!"
echo "   Files are in: $DEST"
echo "   Then run offline_install.sh on your offline system."
