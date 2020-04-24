# Private Packages Manager

Integration de Satis [Satis](https://github.com/composer/satis) dans Packagist [Packagist](https://packagist.org/)
afin d'avoir un système privé
de gestion de packages.

![Image description](https://altiup.com/sites/default/files/img/ppm.png)

################################################################################

**Principe général :**

Ajout d'un script qui récupère dans la base de donnée de Packagist 
les informations sur les packages et qui construit le satis.json


# Config minimum :

- Serveur web (Apache2 ou Nginx)
- PHP 7.3 avec FPM
- Redis
- Certbot
- Serveur Mysql ou MariaDB
- Un compte Algolia (API pour la fonction recherche de Packagist)

# Todo :

* [ ] Faire fonctionner les stats

################################################################################

# Quelques commandes en vrac :

Ajouter un utilisateur au groupe admin (ROLE_ADMIN) :

`app/console fos:user:promote`

Vider le cache :

`app/console cache:clear --env=prod`

# Script de mise à jour Satis à adapter à vos besoins :

`app/satis/bin/update-satis`


################################################################################
################################################################################
################################################################################

# Installation
**(Ces informations sont données à titre indicatif, libre à vous de les adapter)**

# 1 - Dépendances :

# Paquets
```
php7.3 php7.3-zip php7.3-xml php7.3-readline php7.3-opcache php7.3-mysql php7.3-mbstring
php7.3-json php7.3-gd php7.3-fpm php7.3-curl php7.3-common php7.3-cli php-cli php7.3-apc
php-mbstring mariadb-server
```
```
redis-server
apache2
git
curl
unzip
```

# Composer
`curl -sS https://getcomposer.org/installer -o composer-setup.php`

`HASH="$(wget -q -O - https://composer.github.io/installer.sig)"`

`php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"`

`php composer-setup.php --install-dir=/usr/local/bin --filename=composer`

# 2 - Clone du dépôt :

`cd /opt`

`git clone https://github.com/AltiUP/private-packages-manager.git ppm`

# 3 - Creation d'un l'utilisateur spécifique pour PPM

`useradd ppm -d /opt/ppm -M -r`

`usermod -a -G ppm www-data`

`chown -R ppm:ppm /opt/ppm`

# 4 - Serveur web + php :

# PHP-FPM avec utilisateur spécifique
`nano /etc/php/7.3/fpm/pool.d/ppm.conf`

```
[ppm]

listen = /run/php/php7.3-fpm-ppm.sock
listen.owner = ppm
listen.group = ppm
listen.mode = 0666

user = ppm
group = ppm

pm = ondemand
pm.max_children = 16
pm.max_requests = 4000
pm.process_idle_timeout = 10s

php_admin_value[open_basedir] = /opt/packages:/bin:/usr/bin:/usr/local/bin:/tmp:/usr/share
php_admin_value[upload_max_filesize] = 15M
php_admin_value[max_execution_time] = 20
php_admin_value[post_max_size] = 15M
php_admin_value[memory_limit] = 256M
php_admin_value[sendmail_path] = "/usr/sbin/sendmail"
php_admin_flag[mysql.allow_persistent] = off
php_admin_flag[safe_mode] = off

env[PATH] = /usr/local/bin:/usr/bin:/bin
```

`systemctl restart php7.3-fpm`

# Exemple conf Apache2

`nano /etc/apache2/sites-available/ppm.conf`

```
<VirtualHost *:80>
    ServerName ppm.exemple.tld
    DocumentRoot /opt/ppm/web

        # Log format config
        ErrorLog ${APACHE_LOG_DIR}/error-ppm.log
        CustomLog ${APACHE_LOG_DIR}/access-ppm.log combined

        <Directory /opt/ppm/web>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Require all granted
        </Directory>

        # Needed aliases for satis
        Alias /include /opt/ppm/web/include
        Alias /dist /opt/ppm/web/dist
 
        RewriteEngine on

        # SSL
        #SSLEngine on
        #SSLCertificateFile    ppm.exmple.tld.crt
        #SSLCertificateKeyFile   ppm.exemple.tld.key
        #SSLCipherSuite HIGH:!MEDIUM:!aNULL:!MD5:!RC4

        # Security header
        Header set X-XSS-Protection "1; mode=block"
        Header set X-Content-Type-Options: "nosniff"

        # Restreindre certain acces
        #<Files app.php>
        # <RequireAny>
        #    Require ip 10.10.10.10 # Indiquer une IP Privée
        # </RequireAny>
        #</Files>
        #
        #<Files app_dev.php>
        # <RequireAny>
        #    Require ip 10.10.10.10 # Indiquer une IP Privée
        # </RequireAny>
        #</Files>
        #
        #<Files register>
        # <RequireAny>
        #    Require ip 10.10.10.10 # Indiquer une IP Privée
        # </RequireAny>
        #</Files>
        #
        #<Files connect>
        # <RequireAny>
        #    Require ip 10.10.10.10 # Indiquer une IP Privée
        # </RequireAny>
        #</Files>

</VirtualHost>
```
# Activer VirtualHost et modules Apache2

`a2ensite ppm.conf`

`a2enmod rewrite headers proxy proxy_fcgi`

`a2enconf php7.3-fpm`

`systemctl restart apache2`

# Base de données

`mysql -u root`

`CREATE DATABASE ppm;`

`CREATE DATABASE ppm_test;`

`GRANT ALL PRIVILEGES ON ppm.* TO 'ppm'@'localhost' IDENTIFIED BY '<password>';`

`GRANT ALL PRIVILEGES ON ppm_test.* TO 'ppm'@'localhost';`

`FLUSH PRIVILEGES;`

# 5 - Installation de PPM

# Installation des dépendances

Pour Satis :

`cd /opt/ppm/app/satis`

`sudo -u ppm composer install`

Pour Packagist :

`cd /opt/ppm`

`sudo -u ppm composer install`

[A la fin de l'installation, bien penser à renseigner les variables, et surtout le trusted_hosts]

# Creation des tables et nettoyage du cache

`sudo -u ppm app/console doctrine:schema:create`

`sudo -u ppm app/console cache:clear --env=prod`

# Création d'un service Systemd pour le Workers

`nano /etc/systemd/system/ppm-workers.service`

```
[Unit]
Description=Workers PPM
After=redis-server.service

[Service]
Type=simple
User=ppm
Group=ppm
WorkingDirectory=/opt/ppm
SyslogIdentifier=ppm-workers

ExecStart=/opt/ppm/app/console packagist:run-workers
ExecStop=

Restart=on-failure

[Install]
WantedBy=multi-user.target
```

`systemctl enable ppm-workers.service`

`systemctl start ppm-workers.service`

# 6 - Tache cron :


Créer un travail cron dans /etc/cron.d

```
# Ce cron nécessite un utilisateur spécifique.

# Start Packagist
* * * * * ppm /opt/ppm/app/console packagist:update --no-debug --env=prod
* * * * * ppm /opt/ppm/app/console packagist:index --no-debug --env=prod
0 2 * * * ppm /opt/ppm/app/console packagist:stats:compile --no-debug --env=prod
# End Packagist

# Start Satis
*/5 * * * * root /opt/ppm/app/satis/bin/update-satis >> /dev/null 2>&1
# End Satis
```


################################################################################
