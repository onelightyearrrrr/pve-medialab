#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     qbittorrent_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"    # App name
app_uid="$APP_USERNAME"     # App UID
app_guid="$APP_GRPNAME"     # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Installing qBittorrent

#Installing software-properties-common
apt-get install -y curl
apt-get install -y sudo
apt-get install -y mc

# Installing qBittorrent
apt-get install -y qbittorrent-nox

# Create app .service with correct user startup
mkdir -p /.config/qBittorrent/

cat <<EOF >/.config/qBittorrent/qBittorrent.conf
[Preferences]
Downloads\SavePath=/mnt/downloads/torrent/incomplete
WebUI\Password_PBKDF2="@ByteArray(amjeuVrF3xRbgzqWQmes5A==:XK3/Ra9jUmqUc4RwzCtrhrkQIcYczBl90DJw2rT8DFVTss4nxpoRhvyxhCf87ahVE3SzD8K9lyPdpyUCfmVsUg==)"
WebUI\Port=8090
WebUI\UseUPnP=false
WebUI\Username=admin
EOF

cat <<EOF >/etc/systemd/system/qbittorrent-nox.service
[Unit]
Description=qBittorrent client
After=network.target
[Service]
Type=simple
User=$app_uid
Group=$app_guid
UMask=007
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8090
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Start the App
systemctl enable -q --now qbittorrent-nox

#---- Create App backup folder on NAS
if [ -d "/mnt/backup" ]
then
 su - $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------