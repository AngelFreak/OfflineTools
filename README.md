# Offline Package & Docker Downloader/Installer

This repository contains two Bash scripts to facilitate offline installations on Ubuntu systems:

1. **`offline_download.sh`**: Downloads Debian packages (`.deb`) and/or Docker images (`.tar`) on an online machine, saving them into a `setup_<packages>` or `setup_docker_<images>` folder on a USB stick.
2. **`offline_install.sh`**: Installs the downloaded Debian packages and loads the Docker images on the offline machine.

---

## Contents

* [`offline_download.sh`](#offline_downloadsh)
* [`offline_install.sh`](#offline_installsh)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Examples](#examples)
* [Troubleshooting](#troubleshooting)
* [License](#license)

---

## Prerequisites

* **Online machine** (Ubuntu) with:

  * `bash`, `apt-rdepends`, `wget` (optional fallback)
  * `docker` CLI (if downloading images)
  * `sudo` privileges for package cache updates and Docker access.

* **Offline machine** (Ubuntu) with:

  * `bash`, `dpkg`, `apt-get`
  * `docker` CLI (if loading images)
  * Sudo privileges.

---

## `offline_download.sh`

### Description

Downloads the requested `.deb` packages (and dependencies) and/or Docker images on an **online** machine, then moves them into a folder named:

```
setup_<package1>_<package2>_...   or   setup_docker_<image1>_<image2>_...
```

on the same directory as the script (e.g., your USB stick root).

### How it works

1. Prompts for downloading either `.deb` packages or Docker images.
2. Creates a temporary download folder.
3. For `.deb` packages:

   * Updates apt cache.
   * Resolves recursive dependencies via `apt-rdepends`.
   * Handles virtual packages by finding real providers.
   * Downloads each `.deb` with `apt-get download` (or `wget` fallback).
4. For Docker images:

   * Pulls specified images.
   * Saves them into a single `.tar` archive.
   * Corrects ownership for USB access.
5. Moves all `.deb` and `.tar` files into a `setup_...` folder next to the script.

### Usage

```bash
# Make executable
chmod +x offline_download.sh

# Run
./offline_download.sh
```

Follow the interactive prompts to specify package names or Docker image names.

---

## `offline_install.sh`

### Description

Installs `.deb` packages and loads Docker images from **`setup_*`** folders on an **offline** machine.

### How it works

1. Requires root (sudo).
2. Detects all `setup_*` directories in the current folder.
3. Displays a menu to select which setup bundle(s) to process.
4. For each selected bundle:

   * Installs `.deb` files via `dpkg -i`.
   * Loads any Docker image archives (`.tar`) via `docker load -i`.
5. Runs `apt-get install -f --no-download` to fix any package dependencies offline.

### Usage

```bash
# Make executable
chmod +x offline_install.sh

# Run as root
sudo ./offline_install.sh
```

Select the bundle(s) you wish to install.

---

## Examples

1. **Download packages** on online machine:

   ```bash
   ./offline_download.sh
   # Choose option 1, enter "nginx curl"
   ```

   Creates folder `setup_nginx_curl` with `.deb` files.

2. **Download Docker images**:

   ```bash
   ./offline_download.sh
   # Choose option 2, enter "nginx:latest"
   ```

   Creates folder `setup_docker_nginx_latest` with `docker_images_nginx_latest.tar`.

3. **Install on offline machine**:

   ```bash
   sudo ./offline_install.sh
   # Select "nginx_curl" bundle
   ```

---

## Troubleshooting

* **Permission denied connecting to Docker socket**: Ensure your user is in the `docker` group or run Docker commands with sudo.
* **No candidate for a package**: The downloader script handles virtual packages by finding providers. If still skipped, install that provider manually.
* **Missing dependencies**: Ensure all required `.deb` files are present in the `setup_*` folder and run `sudo apt-get install -f --no-download` after.

---

## License

MIT License. Feel free to adapt and extend these scripts for your environment.
