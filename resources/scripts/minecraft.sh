#!/bin/sh

# installing minecraft bedrock server following guidelines
# documented here https://pimylifeup.com/ubuntu-minecraft-bedrock-server/

WORLDNAME=$(hostname)
WORLDSEED='' # no seed by default
WORLDMODE='survival'
WORLDDIFFICULTY='easy'

while getopts 'n:s:m:d:' OPT; do
    case "$OPT" in
      n)
        WORLDNAME="${OPTARG}" ;;
      s)
        WORLDSEED="${OPTARG}" ;;
      m)
        WORLDMODE="${OPTARG}" ;;
      d)
        WORLDDIFFICULTY="${OPTARG}" ;;
    esac
done

# update catalog and upgrade packages
sudo apt-get update && sudo apt-get upgrade -y

# install packages required by minecraft 
sudo apt-get install coreutils curl wget unzip grep screen openssl -y

# initialize minecraft variables
MINECRAFT_USR=$(whoami)
MINECRAFT_DIR="/minecraft"
MINECRAFT_LOG="$MINECRAFT_DIR/log"

# make minecraft user a sudoer
echo "$MINECRAFT_USR  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$MINECRAFT_USR

# initialize minecraft directory
sudo mkdir $MINECRAFT_DIR && sudo mkdir $MINECRAFT_LOG

# download and unpack latest minecraft version
DOWNLOAD_URL=$(curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -s -L -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; BEDROCK-UPDATER)" https://minecraft.net/en-us/download/server/bedrock/ |  grep -o 'https://minecraft.azureedge.net/bin-linux/[^"]*')
sudo wget $DOWNLOAD_URL -O $MINECRAFT_DIR/bedrock-server.zip && sudo unzip $MINECRAFT_DIR/bedrock-server.zip -d $MINECRAFT_DIR/

tee $MINECRAFT_DIR/start.sh <<EOF

sudo screen -L -Logfile $MINECRAFT_LOG/minecraft.\$(date +%Y.%m.%d.%H.%M.%S).log -dmS minecraft /bin/bash -c "LD_LIBRARY_PATH=$MINECRAFT_DIR $MINECRAFT_DIR/bedrock_server"

EOF

tee $MINECRAFT_DIR/stop.sh <<EOF

sudo screen -S minecraft -X quit

EOF

# changing ownership and permissions  
sudo -n chown -R $MINECRAFT_USR $MINECRAFT_DIR
sudo -n chmod -R 755 $MINECRAFT_DIR/*.sh
if [ -e $MINECRAFT_DIR/bedrock_server ]; then
  sudo -n chmod 755 $MINECRAFT_DIR/bedrock_server
  sudo -n chmod +x $MINECRAFT_DIR/bedrock_server
fi

# patching server configuration
sudo sed -i "/level-name=/c\level-name=$WORLDNAME" $MINECRAFT_DIR/server.properties
sudo sed -i "/level-seed=/c\level-seed=$WORLDSEED" $MINECRAFT_DIR/server.properties
sudo sed -i "/gamemode=/c\gamemode=$WORLDMODE" $MINECRAFT_DIR/server.properties
sudo sed -i "/difficulty=/c\difficulty=$WORLDDIFFICULTY" $MINECRAFT_DIR/server.properties

sudo sed -i "/online-mode=/c\online-mode=true" $MINECRAFT_DIR/server.properties
sudo sed -i "/allow-list=/c\allow-list=true" $MINECRAFT_DIR/server.properties
sudo sed -i "/allow-cheats=/c\allow-cheats=false" $MINECRAFT_DIR/server.properties

# open minecraft firewall port
sudo ufw allow 19132 # IPv4
sudo ufw allow 19133 # IPv6

# write minecraft service configuration
tee /etc/systemd/system/minecraft.service <<EOF

[Unit]
Description=Minecraft Bedrock Server
After=network-online.target

[Service]
User=$MINECRAFT_USR
WorkingDirectory=$MINECRAFT_DIR
Type=forking
ExecStart=/bin/bash $MINECRAFT_DIR/start.sh
ExecStop=/bin/bash $MINECRAFT_DIR/stop.sh
GuessMainPID=no
TimeoutStartSec=1800

[Install]
WantedBy=multi-user.target

EOF

# reload service configuration and enable minecraft service
sudo systemctl daemon-reload \
  && sudo systemctl enable minecraft.service \
  && sudo systemctl start minecraft.service

# open dnsmasq firewall port
# sudo ufw allow dns
