#!/usr/bin/env bash
# Vaultwarden-Update (ohne Docker): Backend (alpine) + Web-Vault
# Aufruf:  ./update-vaultwarden.sh
# Aufräumen: ./update-vaultwarden.sh --cleanup-old

set -euo pipefail

VW_DIR="${VW_DIR:-$HOME/vaultwarden}"
SERVICE_NAME="${SERVICE_NAME:-vaultwarden}"
VW_IMAGE="${VW_IMAGE:-vaultwarden/server:alpine}"
WEB_BUILDS_REPO="dani-garcia/bw_web_builds"
EXTRACT_URL="https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract"
DATE_STAMP="$(date +%Y%m%d)"
CLEANUP_OLD=0
DID_BACKUP=0

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { printf 'FEHLER: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Benötigt: $1"; }

usage() {
	cat <<EOF
Usage: $(basename "$0") [--cleanup-old] [--help]

  Aktualisiert Vaultwarden-Binary und Web-Vault in VW_DIR.
  Default: VW_DIR=\$HOME/vaultwarden  SERVICE_NAME=vaultwarden

  --cleanup-old   Entfernt vaultwarden_alt, web-vault_alt und data_backup_*
                  (erst nach erfolgreichem Funktionstest)

Umgebungsvariablen:
  VW_DIR          Installationsverzeichnis
  SERVICE_NAME    systemd --user Unit-Name
  VW_IMAGE        Docker-Image (Default: vaultwarden/server:alpine)
EOF
}

for arg in "$@"; do
	case "$arg" in
		--cleanup-old) CLEANUP_OLD=1 ;;
		-h|--help) usage; exit 0 ;;
		*) die "Unbekanntes Argument: $arg (siehe --help)" ;;
	esac
done

need wget
need tar
need systemctl
need grep
need sed
need head

[[ -d "$VW_DIR" ]] || die "Verzeichnis nicht gefunden: $VW_DIR"
cd "$VW_DIR"

if [[ "$CLEANUP_OLD" -eq 1 ]]; then
	log "Alte Backups entfernen in $VW_DIR …"
	rm -rf vaultwarden_alt web-vault_alt
	rm -rf data_backup_*
	log "Fertig."
	exit 0
fi

[[ -f vaultwarden ]] || die "Keine vaultwarden-Binary in $VW_DIR"
[[ -d data ]] || die "Kein data/-Verzeichnis in $VW_DIR"
[[ -d web-vault ]] || die "Kein web-vault/-Verzeichnis in $VW_DIR"

if [[ -e vaultwarden_alt || -e web-vault_alt ]]; then
	die "vaultwarden_alt oder web-vault_alt existiert bereits. Prüfen oder: $0 --cleanup-old"
fi

fetch_web_vault_url() {
	local api_url json url
	api_url="https://api.github.com/repos/${WEB_BUILDS_REPO}/releases/latest"
	json="$(wget -qO- --header='Accept: application/vnd.github+json' "$api_url")" \
		|| die "GitHub-API für Web-Vault nicht erreichbar"
	url="$(printf '%s\n' "$json" \
		| grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+\.tar\.gz"' \
		| head -n1 \
		| sed -E 's/.*"([^"]+)".*/\1/')"
	[[ -n "$url" ]] || die "Keine .tar.gz in den neuesten bw_web_builds Releases gefunden"
	printf '%s' "$url"
}

rollback() {
	log "Rollback …"
	rm -rf output docker-image-extract web-vault.tar.gz 2>/dev/null || true
	if [[ ! -f vaultwarden && -f vaultwarden_alt ]]; then
		mv vaultwarden_alt vaultwarden
	elif [[ -f vaultwarden_alt ]]; then
		rm -f vaultwarden
		mv vaultwarden_alt vaultwarden
	fi
	if [[ ! -d web-vault && -d web-vault_alt ]]; then
		mv web-vault_alt web-vault
	elif [[ -d web-vault_alt ]]; then
		rm -rf web-vault
		mv web-vault_alt web-vault
	fi
	systemctl --user start "$SERVICE_NAME" 2>/dev/null || true
}

on_error() {
	if [[ "$DID_BACKUP" -eq 1 ]]; then
		rollback
	fi
	die "Update abgebrochen. Prüfe: $VW_DIR und systemctl --user status $SERVICE_NAME"
}
trap on_error ERR

log "1/5 Dienst stoppen: $SERVICE_NAME"
systemctl --user stop "$SERVICE_NAME"

log "2/5 Backup (data → data_backup_${DATE_STAMP})"
if [[ -d "data_backup_${DATE_STAMP}" ]]; then
	die "Backup data_backup_${DATE_STAMP} existiert bereits"
fi
cp -a data "data_backup_${DATE_STAMP}"
mv vaultwarden vaultwarden_alt
mv web-vault web-vault_alt
DID_BACKUP=1

log "3/5 Backend aus Image: $VW_IMAGE"
wget -qO docker-image-extract "$EXTRACT_URL"
chmod +x docker-image-extract
./docker-image-extract "$VW_IMAGE"
[[ -f output/vaultwarden ]] || die "output/vaultwarden fehlt nach Extraktion"
cp output/vaultwarden ./vaultwarden
chmod +x vaultwarden

log "4/5 Web-Vault herunterladen"
WEB_URL="$(fetch_web_vault_url)"
log "    $WEB_URL"
wget -O web-vault.tar.gz "$WEB_URL"
tar -xzf web-vault.tar.gz
[[ -d web-vault ]] || die "Nach Entpacken fehlt web-vault/"

log "5/5 Aufräumen und Dienst starten"
rm -rf output docker-image-extract web-vault.tar.gz
systemctl --user start "$SERVICE_NAME"
sleep 2
systemctl --user --no-pager status "$SERVICE_NAME" || true

if systemctl --user is-active --quiet "$SERVICE_NAME"; then
	trap - ERR
	log "Update OK. Backups behalten: vaultwarden_alt, web-vault_alt, data_backup_${DATE_STAMP}"
	log "Nach Test löschen:  $0 --cleanup-old"
else
	die "Dienst nicht active"
fi
