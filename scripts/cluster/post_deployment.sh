#! /bin/bash
# curl -fsSL https://get.docker.com -o get-docker.sh
# sudo sh get-docker.sh
# sudo usermod -aG docker $USER
# newgrp docker

curl -sS https://webinstall.dev/k9s | bash
sudo mv .local/bin/k9s /usr/bin/