#!/bin/bash

. settings.ini

#Création des répertoires systèmes
. create_sys_dir.sh
create_sys_dir || exit 1

echo "Création du fichier de configuration ..."
if [ ! -f config.py ]; then
  cp config.py.sample config.py || exit 1
fi

echo "préparation du fichier config.py..."
sed -i "s/SQLALCHEMY_DATABASE_URI = .*$/SQLALCHEMY_DATABASE_URI = \"postgresql:\/\/$user_pg:$user_pg_pass@$db_host:$db_port\/$db_name\"/" config.py


# rendre la commande nvm disponible
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
#installation de node et npm et des librairies JS
cd static/
nvm install  || exit 1
nvm use || exit 1
npm ci || exit 1
cd ..

#Installation du virtual env
echo "Installation du virtual env..."


if [[ $python_path ]]; then
  python3 -m venv -p $python_path $venv_dir || exit 1
else
  python3 -m venv $venv_dir || exit 1
fi

source $venv_dir/bin/activate
pip install --upgrade pip || exit 1
pip install -r requirements.txt || exit 1
deactivate

#création d'un fichier de configuration
if [ ! -f static/app/constants.js ]; then
  echo 'Fichier de configuration non existant'
  cp static/app/constants.js.sample static/app/constants.js || exit 1
fi


#affectation des droits sur le répertoire static/medias
chmod -R 775 static/medias || exit 1

#Lancement de l'application
export TAXHUB_DIR=$(readlink -e "${0%/*}")

# Configuration systemd
envsubst '${USER} ${TAXHUB_DIR}' < taxhub.service | sudo tee /etc/systemd/system/taxhub.service || exit 1
sudo systemctl daemon-reload || exit 1

# Configuration apache
sudo cp taxhub_apache.conf /etc/apache2/conf-available/taxhub.conf || exit 1
sudo a2enconf taxhub || exit 1
sudo a2enmod proxy || exit 1
sudo a2enmod proxy_http || exit 1
sudo systemctl reload apache2 || exit 1
# you may need a restart if proxy & proxy_http was not already enabled

echo "Vous pouvez maintenant démarrer TaxHub avec la commande : sudo systemctl start taxhub"
