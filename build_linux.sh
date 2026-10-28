#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Run this build script on Linux; PyInstaller does not cross-compile Windows apps." >&2
  exit 1
fi

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  echo "Activate a Python virtual environment first." >&2
  echo "Example: python3 -m venv .venv && source .venv/bin/activate" >&2
  exit 1
fi

if ! python -c "import PyInstaller, PyQt6, yt_dlp" >/dev/null 2>&1; then
  echo "Install dependencies in the active environment: pip install -r requirements.txt pyinstaller" >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

dist_dir="$script_dir/dist/linux"
package_dir="$script_dir/dist/linux-package"
mkdir -p "$dist_dir" "$package_dir/browser_extension"
mkdir -p "$script_dir/build/linux"

python -m PyInstaller \
  --noconfirm \
  --clean \
  --onefile \
  --name aegis-download-manager \
  --distpath "$dist_dir" \
  --workpath "$script_dir/build/linux" \
  --specpath "$script_dir/build/linux" \
  --add-data "$script_dir/icon.png:." \
  main.py

cp "$dist_dir/aegis-download-manager" "$package_dir/aegis-download-manager"
cp browser_extension/background.js browser_extension/content.js browser_extension/content.css \
  browser_extension/manifest.json "$package_dir/browser_extension/"
cp aegis_host.py ipc_transport.py platform_paths.py \
  "$package_dir/browser_extension/"
cp browser_extension/aegis_host_linux.sh browser_extension/install_host_linux.sh \
  "$package_dir/browser_extension/"
chmod +x "$package_dir/aegis-download-manager" \
  "$package_dir/browser_extension/aegis_host_linux.sh" \
  "$package_dir/browser_extension/install_host_linux.sh"

echo "Linux package created at: $package_dir"
echo "Install system tools as needed: aria2c and ffmpeg"
echo "For browser integration, run browser_extension/install_host_linux.sh from that package."
