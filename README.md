# Offline Package & Docker Installer for Ubuntu

A simple toolkit for installing software on Ubuntu systems without internet access. Download packages and Docker images on an online machine, transfer via USB, and install on your air-gapped system.

## Quick Start

**On your online machine:**
```bash
chmod +x offline_download.sh
./offline_download.sh
# Follow prompts to download packages or Docker images
```

**On your offline machine:**
```bash
chmod +x offline_install.sh
sudo ./offline_install.sh
# Select which bundle(s) to install
```

---

## Table of Contents

- [Overview](#overview)
- [Use Cases](#use-cases)
- [Requirements](#requirements)
- [Step-by-Step Guide](#step-by-step-guide)
  - [Downloading Packages](#downloading-deb-packages)
  - [Downloading Docker Images](#downloading-docker-images)
  - [Installing on Offline Machine](#installing-on-offline-machine)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Limitations](#limitations)
- [License](#license)

---

## Overview

This toolkit solves a common problem: **installing software on systems that have no internet access**.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           WORKFLOW DIAGRAM                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ONLINE MACHINE                         OFFLINE MACHINE                │
│   ──────────────                         ───────────────                │
│                                                                         │
│   1. Run offline_download.sh             4. Run offline_install.sh      │
│          │                                       │                      │
│          ▼                                       ▼                      │
│   2. Downloads packages          ───►    5. Installs packages           │
│      or Docker images           USB         or loads Docker images      │
│          │                      drive            │                      │
│          ▼                                       ▼                      │
│   3. Creates setup_* folder              6. Software ready to use!      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### What's Included

| Script | Purpose |
|--------|---------|
| `offline_download.sh` | Downloads `.deb` packages with all dependencies, or saves Docker images to `.tar` archives |
| `offline_install.sh` | Installs the downloaded packages and loads Docker images on the target system |

---

## Use Cases

- **Air-gapped networks**: Secure environments with no external connectivity
- **Remote deployments**: Field installations where internet is unavailable
- **Embedded systems**: Headless devices requiring offline setup
- **Controlled environments**: Systems where direct internet access is restricted
- **Batch deployments**: Prepare once, deploy to multiple offline machines

---

## Requirements

### Online Machine (where you download)

| Requirement | Notes |
|-------------|-------|
| Ubuntu/Debian system | Uses apt package management |
| `apt-rdepends` | **Required** - Install with `sudo apt install apt-rdepends` |
| `wget` | Optional but recommended for fallback downloads |
| `docker` | Only needed if downloading Docker images |
| Internet access | To download packages/images |
| Removable storage | USB drive or similar for transfer |

### Offline Machine (where you install)

| Requirement | Notes |
|-------------|-------|
| Ubuntu/Debian system | Same or compatible version as online machine |
| `dpkg` and `apt-get` | Pre-installed on Ubuntu |
| `docker` | Only needed if loading Docker images |
| `sudo` access | Required for installation |

> **Important**: The offline machine should run the same Ubuntu version (or compatible) as the online machine to ensure package compatibility.

---

## Step-by-Step Guide

### Downloading .deb Packages

1. **Prepare your online machine**

   First, ensure you have `apt-rdepends` installed:
   ```bash
   sudo apt-get update
   sudo apt-get install apt-rdepends
   ```

2. **Copy scripts to your USB drive**

   Copy both scripts to your USB drive's root directory.

3. **Run the download script**

   ```bash
   cd /media/your-usb-drive
   chmod +x offline_download.sh
   ./offline_download.sh
   ```

4. **Select option 1** for .deb packages

5. **Enter package names** when prompted

   - Space-separated: `nginx curl vim`
   - Or comma-separated: `nginx, curl, vim`

6. **Review the dependency list** and confirm

   The script shows all packages that will be downloaded (including dependencies).

7. **Wait for download to complete**

   A folder named `setup_<packages>` will be created containing all `.deb` files.

### Downloading Docker Images

1. **Ensure Docker is running** on your online machine

   ```bash
   docker info
   ```

2. **Run the download script**

   ```bash
   ./offline_download.sh
   ```

3. **Select option 2** for Docker images

4. **Enter image names** when prompted

   Examples:
   - `nginx:latest`
   - `postgres:15 redis:7`
   - `myregistry.com/myapp:v1.2.3`

5. **Wait for pull and save**

   A folder named `setup_docker_<images>` will be created containing a `.tar` archive.

### Installing on Offline Machine

1. **Connect USB drive** to the offline machine

2. **Navigate to the USB drive**

   ```bash
   cd /media/your-usb-drive
   ```

3. **Run the install script as root**

   ```bash
   sudo ./offline_install.sh
   ```

4. **Select bundles to install**

   The script displays all available `setup_*` folders:
   ```
   Available setup bundles to install/load:
     1) nginx_curl
     2) docker_postgres_redis
     a) Install/Load ALL bundles

   Enter numbers to process (e.g. 1 2), or 'a' for all:
   ```

5. **Wait for installation**

   The script will:
   - Install all `.deb` files with `dpkg`
   - Load all Docker images with `docker load`
   - Attempt to fix any dependency issues

---

## Examples

### Example 1: Installing nginx on an Offline Server

**On online machine:**
```bash
$ ./offline_download.sh

What would you like to download?
   1) .deb packages only
   2) Docker images only
Enter choice [1-2]: 1

Enter package names (space- or comma-separated): nginx

Updating apt cache...
Resolving dependencies...

Will attempt to download these packages:
   • nginx
   • libnginx-mod-http-geoip2
   • nginx-common
   • nginx-core
   ... (additional dependencies)

Proceed? [y/N] y

Downloading .deb packages...
Download complete!
   Files are in: /media/usb/setup_nginx
```

**On offline machine:**
```bash
$ sudo ./offline_install.sh

Available setup bundles to install/load:
  1) nginx

Enter numbers to process (e.g. 1 2), or 'a' for all: 1

Processing bundle: nginx
   Installing .deb packages...
Fixing package dependencies (offline-safe)...
All done!

$ nginx -v
nginx version: nginx/1.24.0
```

### Example 2: Multiple Docker Images

**On online machine:**
```bash
$ ./offline_download.sh

Enter choice [1-2]: 2

Enter Docker image names: postgres:15-alpine redis:7-alpine

Pulling Docker images...
   • postgres:15-alpine
   • redis:7-alpine
Saving all images into: docker_images_postgres_15-alpine_redis_7-alpine.tar
Download complete!
```

**On offline machine:**
```bash
$ sudo ./offline_install.sh

Available setup bundles to install/load:
  1) docker_postgres_15-alpine_redis_7-alpine

Enter numbers to process: 1

Processing bundle: docker_postgres_15-alpine_redis_7-alpine
   Loading Docker images...
     ↪ docker load -i docker_images_postgres_15-alpine_redis_7-alpine.tar
All done!

$ docker images
REPOSITORY   TAG          IMAGE ID       CREATED       SIZE
postgres     15-alpine    abc123...      2 days ago    240MB
redis        7-alpine     def456...      3 days ago    30MB
```

### Example 3: Combined Package and Image Deployment

If you need both packages and Docker images, run the download script twice:

```bash
# First run - download packages
./offline_download.sh    # Choose option 1, enter "docker.io containerd"

# Second run - download images
./offline_download.sh    # Choose option 2, enter "nginx:alpine"
```

Your USB will contain:
```
/media/usb/
├── setup_docker.io_containerd/
│   ├── docker.io_*.deb
│   ├── containerd_*.deb
│   └── ... (dependencies)
├── setup_docker_nginx_alpine/
│   └── docker_images_nginx_alpine.tar
├── offline_download.sh
└── offline_install.sh
```

---

## Troubleshooting

### "apt-rdepends not found"

**Problem**: The download script requires `apt-rdepends` to resolve dependencies.

**Solution**:
```bash
sudo apt-get update
sudo apt-get install apt-rdepends
```

### "Permission denied" connecting to Docker

**Problem**: Docker daemon requires elevated privileges.

**Solutions**:
1. Add your user to the docker group:
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in
   ```
2. Or the script will automatically use `sudo` for Docker commands.

### Virtual package has no candidate

**Problem**: Some packages are "virtual" (meta-packages that don't exist on their own).

**Solution**: The script automatically finds real package providers. If a package is still skipped, manually identify and request the actual package name:
```bash
apt-cache showpkg <virtual-package-name>
# Look for "Reverse Provides" to find real packages
```

### Dependencies still broken after installation

**Problem**: Some dependencies might be missing from the bundle.

**Solutions**:
1. Ensure both machines run the same Ubuntu version
2. Re-run the download with any missing packages added
3. Check the output for "skipped" packages and download those separately

### Docker images fail to load

**Problem**: The `.tar` file might be corrupted or incomplete.

**Solutions**:
1. Verify the file size matches between machines
2. Re-download the images
3. Ensure Docker daemon is running: `sudo systemctl start docker`

### "No setup_* directories found"

**Problem**: The install script can't find any bundles.

**Solution**:
1. Ensure you're running the script from the USB drive root
2. Check that download completed successfully
3. Verify folder names start with `setup_`

---

## FAQ

**Q: Can I download packages for a different Ubuntu version?**

A: The downloaded packages are specific to your Ubuntu version and architecture. For best results, run the download script on a machine with the same Ubuntu version as your target.

**Q: How much space do I need on my USB drive?**

A: It depends on the packages. A simple tool like `curl` needs ~5MB with dependencies. Large applications like Docker can need 500MB+. Check available space before downloading.

**Q: Can I update packages on an offline machine?**

A: Yes! Re-run the download script on your online machine to get the latest versions, then transfer and re-install.

**Q: Does this work with private Docker registries?**

A: Yes, as long as you're logged into the registry on your online machine (`docker login`), you can pull and save private images.

**Q: Can I use this for Debian (not Ubuntu)?**

A: Yes, these scripts should work on any Debian-based system that uses apt and dpkg.

**Q: What if some packages fail to download?**

A: The script continues with remaining packages. Review the output for errors and retry failed packages separately if needed.

---

## Limitations

- **Architecture-specific**: Packages are downloaded for your current CPU architecture (amd64, arm64, etc.)
- **Version-specific**: Best results when online and offline machines run the same OS version
- **No automatic updates**: You must manually re-download to get newer package versions
- **Single-mode downloads**: Each run downloads either packages OR Docker images, not both simultaneously
- **Ubuntu/Debian only**: Designed for apt-based systems

---

## Tips & Best Practices

1. **Test on a similar system first** - Before deploying to production, test the bundle on a non-critical machine with the same OS version.

2. **Keep bundles organized** - Use descriptive package names. The folder name will reflect what you downloaded.

3. **Verify downloads** - Check that all expected files are present before transferring to the offline machine.

4. **Document what you download** - Keep a record of package names and versions for future reference.

5. **Use the same Ubuntu version** - Package compatibility is best when both machines run identical Ubuntu versions.

---

## License

MIT License - Feel free to use, modify, and distribute these scripts.

---

## Contributing

Found a bug or have a suggestion? Open an issue or submit a pull request on GitHub.
