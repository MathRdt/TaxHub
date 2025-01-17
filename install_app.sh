#!/usr/bin/env bash

. settings.ini

echo "Création du fichier de configuration ..."
if [ ! -f config/taxhub_config.toml ]; then
  cp config/taxhub_config.toml.sample config/taxhub_config.toml || exit 1
fi

echo "préparation du fichier config/taxhub_config.toml..."
sed -i "s/SQLALCHEMY_DATABASE_URI = .*$/SQLALCHEMY_DATABASE_URI = \"postgresql:\/\/$user_pg:$user_pg_pass@$db_host:$db_port\/$db_name\"/" config/taxhub_config.toml


#Installation du virtual env
echo "Installation du virtual env..."

python3 -m venv $venv_dir || exit 1

source $venv_dir/bin/activate
pip install --upgrade pip || exit 1
if [ "${mode}" = "dev" ]; then
    pip install -r requirements-dev.txt || exit 1
else
    pip install -r requirements.txt || exit 1
fi
pip install -e . || exit 1
deactivate


#affectation des droits sur le répertoire static/medias
chmod -R 775 static/medias || exit 1

# before 2.0.1 - Déplacement des fichiers médias de taxhub 
# !! ne marche pas si la variable MEDIA_FOLDER est surcouchée
if [ ! -d "media/taxhub" ];then
    mkdir -p "/media/taxhub"
    cp -r /static/medias/* media/taxhub/
fi

#Lancement de l'application
export TAXHUB_DIR=$(readlink -e "${0%/*}")

# Configuration systemd
envsubst '${USER}' < tmpfiles-taxhub.conf | sudo tee /etc/tmpfiles.d/taxhub.conf || exit 1
sudo systemd-tmpfiles --create /etc/tmpfiles.d/taxhub.conf || exit 1
envsubst '${USER} ${TAXHUB_DIR}' < taxhub.service | sudo tee /etc/systemd/system/taxhub.service || exit 1
sudo systemctl daemon-reload || exit 1

# Configuration logrotate
envsubst '${USER}' < log_rotate | sudo tee /etc/logrotate.d/taxhub

# Configuration apache
envsubst '${TAXHUB_DIR}' < taxhub_apache.conf | sudo tee /etc/apache2/conf-available/taxhub.conf || exit 1
sudo a2enmod proxy || exit 1
sudo a2enmod proxy_http || exit 1
# you may need to restart apache2 if proxy & proxy_http was not already enabled

echo "Vous pouvez maintenant démarrer TaxHub avec la commande : sudo systemctl start taxhub"
