#!/usr/bin/env bash

set -Eeuo pipefail

PROMETHEUS_USER="prometheus"
PROMETHEUS_GROUP="prometheus"
PROMETHEUS_CONFIG_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus"
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-}"

if [[ "${EUID}" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

if ! command -v apt-get >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
    echo "This script requires Ubuntu with apt-get and systemd." >&2
    exit 1
fi

${SUDO} apt-get update
${SUDO} apt-get install -y ca-certificates curl jq tar gzip

if [[ -z "${PROMETHEUS_VERSION}" ]]; then
    PROMETHEUS_VERSION="$(${SUDO} curl -fsSL https://api.github.com/repos/prometheus/prometheus/releases/latest | jq -r '.tag_name' | sed 's/^v//')"
fi

if [[ ! "${PROMETHEUS_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid Prometheus version: ${PROMETHEUS_VERSION}" >&2
    exit 1
fi

case "$(dpkg --print-architecture)" in
    amd64) PROMETHEUS_ARCH="amd64" ;;
    arm64) PROMETHEUS_ARCH="arm64" ;;
    armhf) PROMETHEUS_ARCH="armv7" ;;
    i386) PROMETHEUS_ARCH="386" ;;
    *)
        echo "Unsupported Debian architecture: $(dpkg --print-architecture)" >&2
        exit 1
        ;;
esac

PROMETHEUS_RELEASE="prometheus-${PROMETHEUS_VERSION}.linux-${PROMETHEUS_ARCH}"
PROMETHEUS_BASE_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

${SUDO} groupadd --system "${PROMETHEUS_GROUP}" 2>/dev/null || true
if ! id "${PROMETHEUS_USER}" >/dev/null 2>&1; then
    ${SUDO} useradd --system --no-create-home --shell /usr/sbin/nologin --gid "${PROMETHEUS_GROUP}" "${PROMETHEUS_USER}"
fi

${SUDO} curl -fsSL -o "${TEMP_DIR}/${PROMETHEUS_RELEASE}.tar.gz" "${PROMETHEUS_BASE_URL}/${PROMETHEUS_RELEASE}.tar.gz"
${SUDO} curl -fsSL -o "${TEMP_DIR}/sha256sums.txt" "${PROMETHEUS_BASE_URL}/sha256sums.txt"

EXPECTED_CHECKSUM="$(awk -v file="${PROMETHEUS_RELEASE}.tar.gz" '$2 == file { print $1; exit }' "${TEMP_DIR}/sha256sums.txt")"
if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
    echo "No checksum found for ${PROMETHEUS_RELEASE}.tar.gz" >&2
    exit 1
fi
echo "${EXPECTED_CHECKSUM}  ${TEMP_DIR}/${PROMETHEUS_RELEASE}.tar.gz" | sha256sum --check --status -

tar -xzf "${TEMP_DIR}/${PROMETHEUS_RELEASE}.tar.gz" -C "${TEMP_DIR}"
${SUDO} install -m 0755 "${TEMP_DIR}/${PROMETHEUS_RELEASE}/prometheus" /usr/local/bin/prometheus
${SUDO} install -m 0755 "${TEMP_DIR}/${PROMETHEUS_RELEASE}/promtool" /usr/local/bin/promtool
${SUDO} install -d -o "${PROMETHEUS_USER}" -g "${PROMETHEUS_GROUP}" "${PROMETHEUS_CONFIG_DIR}" "${PROMETHEUS_DATA_DIR}"
${SUDO} install -d -o "${PROMETHEUS_USER}" -g "${PROMETHEUS_GROUP}" "${PROMETHEUS_CONFIG_DIR}/consoles" "${PROMETHEUS_CONFIG_DIR}/console_libraries"
${SUDO} cp -r "${TEMP_DIR}/${PROMETHEUS_RELEASE}/consoles/." "${PROMETHEUS_CONFIG_DIR}/consoles/"
${SUDO} cp -r "${TEMP_DIR}/${PROMETHEUS_RELEASE}/console_libraries/." "${PROMETHEUS_CONFIG_DIR}/console_libraries/"

if [[ ! -f "${PROMETHEUS_CONFIG_DIR}/prometheus.yml" ]]; then
    ${SUDO} tee "${PROMETHEUS_CONFIG_DIR}/prometheus.yml" >/dev/null <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
EOF
fi

${SUDO} chown -R "${PROMETHEUS_USER}:${PROMETHEUS_GROUP}" "${PROMETHEUS_CONFIG_DIR}" "${PROMETHEUS_DATA_DIR}"
${SUDO} chmod 0755 "${PROMETHEUS_CONFIG_DIR}"
${SUDO} chmod 0644 "${PROMETHEUS_CONFIG_DIR}/prometheus.yml"

${SUDO} tee /etc/systemd/system/prometheus.service >/dev/null <<EOF
[Unit]
Description=Prometheus monitoring service
Wants=network-online.target
After=network-online.target

[Service]
User=${PROMETHEUS_USER}
Group=${PROMETHEUS_GROUP}
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=${PROMETHEUS_CONFIG_DIR}/prometheus.yml \\
  --storage.tsdb.path=${PROMETHEUS_DATA_DIR} \\
  --web.console.templates=${PROMETHEUS_CONFIG_DIR}/consoles \\
  --web.console.libraries=${PROMETHEUS_CONFIG_DIR}/console_libraries
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

${SUDO} systemctl daemon-reload
${SUDO} systemctl enable --now prometheus
${SUDO} systemctl restart prometheus

if ! ${SUDO} systemctl is-active --quiet prometheus; then
    ${SUDO} systemctl --no-pager --full status prometheus || true
    exit 1
fi

for attempt in {1..15}; do
    if curl -fsS http://127.0.0.1:9090/-/ready >/dev/null; then
        echo "Prometheus ${PROMETHEUS_VERSION} is running at http://127.0.0.1:9090"
        exit 0
    fi
    sleep 1
done

echo "Prometheus service is active but did not become ready." >&2
${SUDO} journalctl -u prometheus --no-pager -n 50 || true
exit 1
