# Private Package Manager

Fork de l'excellent Packagist couplé à Satis

########################################################

# Installation

# 1 - Dépedances :

# PHP
`apt install php7.3 php7.3-zip php7.3-xml php7.3-readline php7.3-opcache php7.3-mysql php7.3-mbstring php7.3-json php7.3-gd php7.3-fpm php7.3-curl php7.3-common php7.3-cli php-cli php7.3-apc php-mbstring mariadb-server redis-server apache2 git curl unzip`

# Composer
`curl -sS https://getcomposer.org/installer -o composer-setup.php`

`HASH="$(wget -q -O - https://composer.github.io/installer.sig)"`

`php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"`

`php composer-setup.php --install-dir=/usr/local/bin --filename=composer`

# 2 - Téléchargement du dépôt :

`cd /opt`

`git clone https://`

# 3 - Creation de l'utilisateur

`useradd ppm -d /opt/ppm -M -r`

`usermod -a -G ppm www-data`

`chown -R ppm:ppm /opt/ppm`

# 4 - Serveur web + php :

# PHP-FPM
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

# Apache2

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

        <Directory /opt/ppm/web/satis>
                Options -Indexes
                AllowOverride All
                Require all granted
        </Directory>

        # Needed aliases for satis
        Alias /satis /opt/ppm/web/satis
        Alias /include /opt/ppm/web/satis/include
        Alias /dist /opt/ppm/web/satis/dist
 
        RewriteEngine on

        # Push packages list to satis list to allow distribution files
        RewriteRule ^/?(packages\.json)$ "/satis/$1" [R=301,L]

        # SSL
        #SSLEngine on
        #SSLCertificateFile    ppm.exmple.tld.crt
        #SSLCertificateKeyFile   ppm.exemple.tld.key
        #SSLCipherSuite HIGH:!MEDIUM:!aNULL:!MD5:!RC4

        # Security header
        Header set X-XSS-Protection "1; mode=block"
        Header set X-Content-Type-Options: "nosniff"

        # Restreindre certain acces
        <Files app.php>
         <RequireAny>
            Require ip 10.10.10.10 # Indiquer une IP Privée
         </RequireAny>
        </Files>

        <Files app_dev.php>
         <RequireAny>
            Require ip 10.10.10.10 # Indiquer une IP Privée
         </RequireAny>
        </Files>

        <Files register>
         <RequireAny>
            Require ip 10.10.10.10 # Indiquer une IP Privée
         </RequireAny>
        </Files>

        <Files connect>
         <RequireAny>
            Require ip 10.10.10.10 # Indiquer une IP Privée
         </RequireAny>
        </Files>

</VirtualHost>
```

`a2ensite ppm.conf`

`a2enmod rewrite`

`a2enmod headers`

`a2enmod proxy`

`a2enmod proxy_fcgi`

`a2enconf php7.3-fpm`

`systemctl restart apache2`

# MariaDB

`mysql -u root`

`CREATE DATABASE ppm;`

`CREATE DATABASE ppm_test;`

`GRANT ALL PRIVILEGES ON ppm.* TO 'ppm'@'localhost' IDENTIFIED BY '<password>';`

`GRANT ALL PRIVILEGES ON ppm_test.* TO 'ppm'@'localhost';`

`FLUSH PRIVILEGES;`

# 5 - Installation de PPM

# Installation des dépendances

`cd /opt/ppm`

`sudo -u ppm composer install`

# Creation des tables

`sudo -u ppm app/console doctrine:schema:create`
