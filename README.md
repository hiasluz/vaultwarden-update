# Vaultwarden Update (ohne Docker)

Bash-Skript zum Aktualisieren einer Vaultwarden-Installation unter `~/vaultwarden` (systemd user service). Geeignet für Hostsharing und ähnliche Setups ohne Docker.

**Repo:** https://github.com/hiasluz/vaultwarden-update

## Voraussetzungen

- Linux mit `systemd --user`
- `wget`, `tar`
- Layout:

```
~/vaultwarden/
  vaultwarden
  web-vault/
  data/
```

## Hostsharing: ein Befehl (empfohlen)

Skript nach `/tmp` laden, Update ausführen, danach wieder löschen — nichts bleibt in der Installation:

```bash
TMP=$(mktemp -d) && wget -qO "$TMP/update-vaultwarden.sh" "https://raw.githubusercontent.com/hiasluz/vaultwarden-update/main/update-vaultwarden.sh" && bash "$TMP/update-vaultwarden.sh"; rm -rf "$TMP"
```

Anderes Installationsverzeichnis:

```bash
TMP=$(mktemp -d) && wget -qO "$TMP/update-vaultwarden.sh" "https://raw.githubusercontent.com/hiasluz/vaultwarden-update/main/update-vaultwarden.sh" && VW_DIR="$HOME/vaultwarden" bash "$TMP/update-vaultwarden.sh"; rm -rf "$TMP"
```

Alte Backups nach erfolgreichem Test entfernen:

```bash
TMP=$(mktemp -d) && wget -qO "$TMP/update-vaultwarden.sh" "https://raw.githubusercontent.com/hiasluz/vaultwarden-update/main/update-vaultwarden.sh" && bash "$TMP/update-vaultwarden.sh" --cleanup-old; rm -rf "$TMP"
```

Hinweis: `rm -rf "$TMP"` läuft auch bei fehlgeschlagenem Update (`;` vor dem Löschen).

## Lokal / dauerhaft geklont

```bash
git clone https://github.com/hiasluz/vaultwarden-update.git
cd vaultwarden-update
chmod +x update-vaultwarden.sh
./update-vaultwarden.sh
```

## Was passiert

1. Service stoppen, `data` sichern, Binary/`web-vault` → `*_alt`
2. Backend aus `vaultwarden/server:alpine` (docker-image-extract)
3. Neuestes Web-Vault von [bw_web_builds](https://github.com/dani-garcia/bw_web_builds/releases/latest)
4. Aufräumen, Service starten; bei Fehler Rollback

## Lizenz

[MIT](LICENSE)
