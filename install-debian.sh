#!/bin/bash

# Private Packages Manager

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
export DEBIAN_FRONTEND=noninteractive
VERSION='debian'
PPM='/opt/ppm'
memory=$(grep 'MemTotal' /proc/meminfo |tr ' ' '\n' |grep [0-9])
arch=$(uname -i)
os='debian'
release=$(cat /etc/debian_version|grep -o [0-9]|head -n1)
codename="$(cat /etc/os-release |grep VERSION= |cut -f 2 -d \(|cut -f 1 -d \))"
ppminstall="$PPM/install/$VERSION/$release"

if [ "$release" -eq 10 ]; then
    software="php7.3 php7.3-zip php7.3-xml php7.3-readline 
        php7.3-opcache php7.3-mysql php7.3-mbstring php7.3-json 
        php7.3-gd php7.3-fpm php7.3-curl php7.3-common php7.3-cli 
        php-cli php7.3-apc php-mbstring mariadb-server redis-server 
        apache2 git curl unzip sudo"
else [ "$release" -eq 9 ]
    software="php7.3 php7.3-zip php7.3-xml php7.3-readline 
        php7.3-opcache php7.3-mysql php7.3-mbstring php7.3-json 
        php7.3-gd php7.3-fpm php7.3-curl php7.3-common php7.3-cli 
        php-cli php7.3-apc php-mbstring mariadb-server redis-server 
        apache2 git curl unzip sudo"
fi

# Defining help function
help() {
    echo "Usage: $0 [OPTIONS]
  -a, --apache            Install Apache        [yes|no]  default: yes
  -n, --nginx             Install Nginx         [yes|no]  default: yes
  -l, --lang              Default language                default: en
  -y, --interactive       Interactive install   [yes|no]  default: yes
  -s, --hostname          Set hostname
  -e, --email             Set admin email
  -p, --password          Set admin password
  -f, --force             Force installation
  -h, --help              Print this help

  Example: bash $0 -e demo@exemple.tld -p p4ssw0rd --apache yes"
    exit 1
}


# Defining password-gen function
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=10
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}

# Defning return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

# Defining function to set default value
set_default_value() {
    eval variable=\$$1
    if [ -z "$variable" ]; then
        eval $1=$2
    fi
    if [ "$variable" != 'yes' ] && [ "$variable" != 'no' ]; then
        eval $1=$2
    fi
}

# Define function to set default language value
set_default_lang() {
    if [ -z "$lang" ]; then
        eval lang=$1
    fi
    lang_list="
        ar cz el fa hu ja no pt se ua
        bs da en fi id ka pl ro tr vi
        cn de es fr it nl pt-BR ru tw
        bg ko sr th ur"
    if !(echo $lang_list |grep -w $lang 1>&2>/dev/null); then
        eval lang=$1
    fi
}


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Creating temporary file
tmpfile=$(mktemp -p /tmp)

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --apache)               args="${args}-a " ;;
        --nginx)                args="${args}-n " ;;
        --lang)                 args="${args}-l " ;;
        --interactive)          args="${args}-y " ;;
        --hostname)             args="${args}-s " ;;
        --email)                args="${args}-e " ;;
        --password)             args="${args}-p " ;;
        --force)                args="${args}-f " ;;
        --help)                 args="${args}-h " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "a:n:l:y:s:e:p:fh" Option; do
    case $Option in
        a) apache=$OPTARG ;;            # Apache
        n) nginx=$OPTARG ;;             # Nginx
        l) lang=$OPTARG ;;              # Language
        y) interactive=$OPTARG ;;       # Interactive install
        s) servername=$OPTARG ;;        # Hostname
        e) email=$OPTARG ;;             # Admin email
        p) vpass=$OPTARG ;;             # Admin password
        f) force='yes' ;;               # Force install
        h) help ;;                      # Help
        *) help ;;                      # Print help (default)
    esac
done

# Defining default software stack
set_default_value 'nginx' 'no'
set_default_value 'apache' 'yes'
set_default_value 'interactive' 'yes'
set_default_lang 'fr'

# Checking root permissions
if [ "x$(id -u)" != 'x0' ]; then
    check_error 1 "Script can be run executed only by root"
fi

# Checking admin user account
if [ ! -z "$(grep ^ppm: /etc/passwd)" ] && [ -z "$force" ]; then
    echo 'Please remove ppm user account before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo -e "Example: bash $0 --force\n"
    check_result 1 "User ppm exists"
fi

# Checking wget
if [ ! -e '/usr/bin/wget' ]; then
    apt-get -y install wget
    check_result $? "Can't install wget"
fi

# Check installed packages
tmpfile=$(mktemp -p /tmp)
dpkg --get-selections > $tmpfile
for pkg in mysql-server mariadb-server apache2 nginx; do
    if [ ! -z "$(grep $pkg $tmpfile)" ]; then
        conflicts="$pkg $conflicts"
    fi
done
rm -f $tmpfile
if [ ! -z "$conflicts" ] && [ -z "$force" ]; then
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    echo 'Following packages are already installed:'
    echo "$conflicts"
    echo
    echo 'It is highly recommended to remove them before proceeding.'
    echo 'If you want to force installation run this script with -f option:'
    echo "Example: bash $0 --force"
    echo
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    check_result 1 "Private Packages Manager should be installed on clean server."
fi


#----------------------------------------------------------#
#                       Brief Info                         #
#----------------------------------------------------------#

# Printing nice ascii aslogo
clear
echo
echo ' _|_|_|_|_|    _|_|_|_|_|     _|_|_|   _|_|_|'
echo ' _|      _|    _|      _|     _|   _|  _|  _|'
echo ' _|_|_|_|_|    _|_|_|_|_|     _|    _|_|   _|'
echo ' _|            _|             _|           _|'
echo ' _|            _|             _|           _|'
echo
echo '                     Private Packages Manager'
echo -e "\n\n"

echo 'Following software will be installed on your system:'

# Web stack
if [ "$nginx" = 'yes' ]; then
    echo '   - Nginx Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo '   - Apache Web Server'
fi

# Asking for confirmation to proceed
if [ "$interactive" = 'yes' ]; then
    read -p 'Would you like to continue [y/n]: ' answer
    if [ "$answer" != 'y' ] && [ "$answer" != 'Y'  ]; then
        echo 'Goodbye'
        exit 1
    fi
fi

# Printing start message and sleeping for 5 seconds
echo -e "\n\n\n\nInstallation will take about 15 minutes ...\n"
sleep 5


#----------------------------------------------------------#
#                      Checking swap                       #
#----------------------------------------------------------#

# Checking swap on small instances
if [ -z "$(swapon -s)" ] && [ $memory -lt 1000000 ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
fi


#----------------------------------------------------------#
#                   Upgrade repository                     #
#----------------------------------------------------------#

# Updating system
apt-get -y upgrade
check_result $? 'apt-get upgrade failed'


#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#

# Update system packages
apt-get update

# Disable daemon autostart /usr/share/doc/sysv-rc/README.policy-rc.d.gz
echo -e '#!/bin/sh \nexit 101' > /usr/sbin/policy-rc.d
chmod a+x /usr/sbin/policy-rc.d

# Install apt packages
apt-get -y install $software
check_result $? "apt-get install failed"

# Restore  policy
rm -f /usr/sbin/policy-rc.d


#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

# Set directory color
echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile

# NTP Synchronization
echo '#!/bin/sh' > /etc/cron.daily/ntpdate
echo "$(which ntpdate) -s pool.ntp.org" >> /etc/cron.daily/ntpdate
chmod 775 /etc/cron.daily/ntpdate
ntpdate -s pool.ntp.org


#----------------------------------------------------------#
#                     Configure PPM                        #
#----------------------------------------------------------#

# Configuring logrotate for Vesta logs
cp -f $vestacp/logrotate/vesta /etc/logrotate.d/

# Building directory tree and creating some blank files for vesta
mkdir -p $VESTA/conf $VESTA/log $VESTA/ssl $VESTA/data/ips \
    $VESTA/data/queue $VESTA/data/users $VESTA/data/firewall \
    $VESTA/data/sessions
touch $VESTA/data/queue/backup.pipe $VESTA/data/queue/disk.pipe \
    $VESTA/data/queue/webstats.pipe $VESTA/data/queue/restart.pipe \
    $VESTA/data/queue/traffic.pipe $VESTA/log/system.log \
    $VESTA/log/nginx-error.log $VESTA/log/auth.log
chmod 750 $VESTA/conf $VESTA/data/users $VESTA/data/ips $VESTA/log
chmod -R 750 $VESTA/data/queue
chmod 660 $VESTA/log/*
rm -f /var/log/vesta
ln -s $VESTA/log /var/log/vesta
chown admin:admin $VESTA/data/sessions
chmod 770 $VESTA/data/sessions

# Generating vesta configuration
rm -f $VESTA/conf/vesta.conf 2>/dev/null
touch $VESTA/conf/vesta.conf
chmod 660 $VESTA/conf/vesta.conf

# WEB stack
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo "WEB_SYSTEM='apache2'" >> $VESTA/conf/vesta.conf
    echo "WEB_RGROUPS='www-data'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='mod_ssl'"  >> $VESTA/conf/vesta.conf
    echo "STATS_SYSTEM='webalizer,awstats'" >> $VESTA/conf/vesta.conf
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo "WEB_SYSTEM='apache2'" >> $VESTA/conf/vesta.conf
    echo "WEB_RGROUPS='www-data'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='8080'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='8443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='mod_ssl'"  >> $VESTA/conf/vesta.conf
    echo "PROXY_SYSTEM='nginx'" >> $VESTA/conf/vesta.conf
    echo "PROXY_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "PROXY_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "STATS_SYSTEM='webalizer,awstats'" >> $VESTA/conf/vesta.conf
fi
if [ "$apache" = 'no' ] && [ "$nginx"  = 'yes' ]; then
    echo "WEB_SYSTEM='nginx'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='openssl'"  >> $VESTA/conf/vesta.conf
    if [ "$release" -eq 9 ]; then
        if [ "$phpfpm" = 'yes' ]; then
            echo "WEB_BACKEND='php-fpm'" >> $VESTA/conf/vesta.conf
        fi
    else
        if [ "$phpfpm" = 'yes' ]; then
            echo "WEB_BACKEND='php5-fpm'" >> $VESTA/conf/vesta.conf
        fi
    fi
    echo "STATS_SYSTEM='webalizer,awstats'" >> $VESTA/conf/vesta.conf
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='vsftpd'" >> $VESTA/conf/vesta.conf
fi
if [ "$proftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='proftpd'" >> $VESTA/conf/vesta.conf
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo "DNS_SYSTEM='bind9'" >> $VESTA/conf/vesta.conf
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo "MAIL_SYSTEM='exim4'" >> $VESTA/conf/vesta.conf
    if [ "$clamd" = 'yes'  ]; then
        echo "ANTIVIRUS_SYSTEM='clamav-daemon'" >> $VESTA/conf/vesta.conf
    fi
    if [ "$spamd" = 'yes' ]; then
        echo "ANTISPAM_SYSTEM='spamassassin'" >> $VESTA/conf/vesta.conf
    fi
    if [ "$dovecot" = 'yes' ]; then
        echo "IMAP_SYSTEM='dovecot'" >> $VESTA/conf/vesta.conf
    fi
fi

# CRON daemon
echo "CRON_SYSTEM='cron'" >> $VESTA/conf/vesta.conf

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo "FIREWALL_SYSTEM='iptables'" >> $VESTA/conf/vesta.conf
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo "FIREWALL_EXTENSION='fail2ban'" >> $VESTA/conf/vesta.conf
fi

# Disk quota
if [ "$quota" = 'yes' ]; then
    echo "DISK_QUOTA='yes'" >> $VESTA/conf/vesta.conf
fi

# Backups
echo "BACKUP_SYSTEM='local'" >> $VESTA/conf/vesta.conf

# Language
echo "LANGUAGE='$lang'" >> $VESTA/conf/vesta.conf

# Version
echo "VERSION='0.9.8'" >> $VESTA/conf/vesta.conf

# Installing hosting packages
cp -rf $vestacp/packages $VESTA/data/

# Installing templates
cp -rf $vestacp/templates $VESTA/data/

# Copying index.html to default documentroot
cp $VESTA/data/templates/web/skel/public_html/index.html /var/www/
sed -i 's/%domain%/It worked!/g' /var/www/index.html

# Installing firewall rules
cp -rf $vestacp/firewall $VESTA/data/

# Configuring server hostname
$VESTA/bin/v-change-sys-hostname $servername 2>/dev/null

# Generating SSL certificate
$VESTA/bin/v-generate-ssl-cert $(hostname) $email 'US' 'California' \
     'San Francisco' 'Vesta Control Panel' 'IT' > /tmp/vst.pem

# Parsing certificate file
crt_end=$(grep -n "END CERTIFICATE-" /tmp/vst.pem |cut -f 1 -d:)
key_start=$(grep -n "BEGIN RSA" /tmp/vst.pem |cut -f 1 -d:)
key_end=$(grep -n  "END RSA" /tmp/vst.pem |cut -f 1 -d:)

# Adding SSL certificate
cd $VESTA/ssl
sed -n "1,${crt_end}p" /tmp/vst.pem > certificate.crt
sed -n "$key_start,${key_end}p" /tmp/vst.pem > certificate.key
chown root:mail $VESTA/ssl/*
chmod 660 $VESTA/ssl/*
rm /tmp/vst.pem


#----------------------------------------------------------#
#                     Configure Nginx                      #
#----------------------------------------------------------#

if [ "$nginx" = 'yes' ]; then
    rm -f /etc/nginx/conf.d/*.conf
    cp -f $vestacp/nginx/nginx.conf /etc/nginx/
    cp -f $vestacp/nginx/status.conf /etc/nginx/conf.d/
    cp -f $vestacp/nginx/phpmyadmin.inc /etc/nginx/conf.d/
    cp -f $vestacp/nginx/phppgadmin.inc /etc/nginx/conf.d/
    cp -f $vestacp/nginx/webmail.inc /etc/nginx/conf.d/
    cp -f $vestacp/logrotate/nginx /etc/logrotate.d/
    echo > /etc/nginx/conf.d/vesta.conf
    mkdir -p /var/log/nginx/domains
    update-rc.d nginx defaults
    service nginx start
    check_result $? "nginx start failed"
fi


#----------------------------------------------------------#
#                    Configure Apache                      #
#----------------------------------------------------------#

if [ "$apache" = 'yes'  ]; then
    cp -f $vestacp/apache2/apache2.conf /etc/apache2/
    cp -f $vestacp/apache2/status.conf /etc/apache2/mods-enabled/
    cp -f  $vestacp/logrotate/apache2 /etc/logrotate.d/
    a2enmod rewrite
    a2enmod suexec
    a2enmod ssl
    a2enmod actions
    a2enmod ruid2
    a2enmod headers
    mkdir -p /etc/apache2/conf.d
    echo > /etc/apache2/conf.d/vesta.conf
    echo "# Powered by vesta" > /etc/apache2/sites-available/default
    echo "# Powered by vesta" > /etc/apache2/sites-available/default-ssl
    echo "# Powered by vesta" > /etc/apache2/ports.conf
    echo -e "/home\npublic_html/cgi-bin" > /etc/apache2/suexec/www-data
    touch /var/log/apache2/access.log /var/log/apache2/error.log
    mkdir -p /var/log/apache2/domains
    chmod a+x /var/log/apache2
    chmod 640 /var/log/apache2/access.log /var/log/apache2/error.log
    chmod 751 /var/log/apache2/domains
    update-rc.d apache2 defaults
    service apache2 start
    check_result $? "apache2 start failed"
else
    update-rc.d apache2 disable >/dev/null 2>&1
    service apache2 stop >/dev/null 2>&1
fi


#----------------------------------------------------------#
#                     Configure PHP-FPM                    #
#----------------------------------------------------------#

if [ "$phpfpm" = 'yes' ]; then
    if [ "$release" -eq 9 ]; then
        cp -f $vestacp/php-fpm/www.conf /etc/php/7.0/fpm/pool.d/www.conf
        update-rc.d php7.0-fpm defaults
        service php7.0-fpm start
        check_result $? "php-fpm start failed"
    else
        cp -f $vestacp/php5-fpm/www.conf /etc/php5/fpm/pool.d/www.conf
        update-rc.d php5-fpm defaults
        service php5-fpm start
        check_result $? "php-fpm start failed"
    fi
fi


#----------------------------------------------------------#
#                     Configure PHP                        #
#----------------------------------------------------------#

ZONE=$(timedatectl 2>/dev/null|grep Timezone|awk '{print $2}')
if [ -z "$ZONE" ]; then
    ZONE='UTC'
fi
for pconf in $(find /etc/php* -name php.ini); do
    sed -i "s/;date.timezone =/date.timezone = $ZONE/g" $pconf
    sed -i 's%_open_tag = Off%_open_tag = On%g' $pconf
done


#----------------------------------------------------------#
#                    Configure VSFTPD                      #
#----------------------------------------------------------#

if [ "$vsftpd" = 'yes' ]; then
    cp -f $vestacp/vsftpd/vsftpd.conf /etc/
    update-rc.d vsftpd defaults
    service vsftpd start
    check_result $? "vsftpd start failed"

    # To be deleted after release 0.9.8-18
    echo "/sbin/nologin" >> /etc/shells
fi


#----------------------------------------------------------#
#                    Configure ProFTPD                     #
#----------------------------------------------------------#

if [ "$proftpd" = 'yes' ]; then
    echo "127.0.0.1 $servername" >> /etc/hosts
    cp -f $vestacp/proftpd/proftpd.conf /etc/proftpd/
    update-rc.d proftpd defaults
    service proftpd start
    check_result $? "proftpd start failed"
fi


#----------------------------------------------------------#
#                  Configure MySQL/MariaDB                 #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ]; then
    mycnf="my-small.cnf"
    if [ $memory -gt 1200000 ]; then
        mycnf="my-medium.cnf"
    fi
    if [ $memory -gt 3900000 ]; then
        mycnf="my-large.cnf"
    fi

    # MySQL configuration
    cp -f $vestacp/mysql/$mycnf /etc/mysql/my.cnf
    mysql_install_db
    update-rc.d mysql defaults
    service mysql start
    check_result $? "mysql start failed"

    # Securing MySQL installation
    mpass=$(gen_pass)
    mysqladmin -u root password $mpass
    echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
    chmod 600 /root/.my.cnf
    mysql -e "DELETE FROM mysql.user WHERE User=''"
    mysql -e "DROP DATABASE test" >/dev/null 2>&1
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -e "DELETE FROM mysql.user WHERE user='' or password='';"
    mysql -e "FLUSH PRIVILEGES"

    # Configuring phpMyAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $vestacp/pma/apache.conf /etc/phpmyadmin/
        ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf.d/phpmyadmin.conf
    fi
    cp -f $vestacp/pma/config.inc.php /etc/phpmyadmin/
    chmod 777 /var/lib/phpmyadmin/tmp
fi

#----------------------------------------------------------#
#                   Configure PostgreSQL                   #
#----------------------------------------------------------#

if [ "$postgresql" = 'yes' ]; then
    ppass=$(gen_pass)
    cp -f $vestacp/postgresql/pg_hba.conf /etc/postgresql/*/main/
    service postgresql restart
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"

    # Configuring phpPgAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $vestacp/pga/phppgadmin.conf /etc/apache2/conf.d/
    fi
    cp -f $vestacp/pga/config.inc.php /etc/phppgadmin/
fi


#----------------------------------------------------------#
#                      Configure Bind                      #
#----------------------------------------------------------#

if [ "$named" = 'yes' ]; then
    cp -f $vestacp/bind/named.conf /etc/bind/
    sed -i "s%listen-on%//listen%" /etc/bind/named.conf.options
    chown root:bind /etc/bind/named.conf
    chmod 640 /etc/bind/named.conf
    aa-complain /usr/sbin/named 2>/dev/null
    echo "/home/** rwm," >> /etc/apparmor.d/local/usr.sbin.named 2>/dev/null
    service apparmor status >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        service apparmor restart
    fi
    update-rc.d bind9 defaults
    service bind9 start
    check_result $? "bind9 start failed"
fi

#----------------------------------------------------------#
#                      Configure Exim                      #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ]; then
    gpasswd -a Debian-exim mail
    cp -f $vestacp/exim/exim4.conf.template /etc/exim4/
    cp -f $vestacp/exim/dnsbl.conf /etc/exim4/
    cp -f $vestacp/exim/spam-blocks.conf /etc/exim4/
    touch /etc/exim4/white-blocks.conf

    if [ "$spamd" = 'yes' ]; then
        sed -i "s/#SPAM/SPAM/g" /etc/exim4/exim4.conf.template
    fi
    if [ "$clamd" = 'yes' ]; then
        sed -i "s/#CLAMD/CLAMD/g" /etc/exim4/exim4.conf.template
    fi

    chmod 640 /etc/exim4/exim4.conf.template
    rm -rf /etc/exim4/domains
    mkdir -p /etc/exim4/domains

    rm -f /etc/alternatives/mta
    ln -s /usr/sbin/exim4 /etc/alternatives/mta
    update-rc.d -f sendmail remove > /dev/null 2>&1
    service sendmail stop > /dev/null 2>&1
    update-rc.d -f postfix remove > /dev/null 2>&1
    service postfix stop > /dev/null 2>&1

    update-rc.d exim4 defaults
    service exim4 start
    check_result $? "exim4 start failed"
fi


#----------------------------------------------------------#
#                     Configure Dovecot                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ]; then
    gpasswd -a dovecot mail
    cp -rf $vestacp/dovecot /etc/
    cp -f $vestacp/logrotate/dovecot /etc/logrotate.d/
    chown -R root:root /etc/dovecot*
    if [ "$release" -eq 9 ]; then
        sed -i "s#namespace inbox {#namespace inbox {\n  inbox = yes#" /etc/dovecot/conf.d/15-mailboxes.conf
    fi
    update-rc.d dovecot defaults
    service dovecot start
    check_result $? "dovecot start failed"
fi


#----------------------------------------------------------#
#                     Configure ClamAV                     #
#----------------------------------------------------------#

if [ "$clamd" = 'yes' ]; then
    gpasswd -a clamav mail
    gpasswd -a clamav Debian-exim
    cp -f $vestacp/clamav/clamd.conf /etc/clamav/
    /usr/bin/freshclam
    update-rc.d clamav-daemon defaults
    if [ ! -d "/var/run/clamav" ]; then
        mkdir /var/run/clamav
    fi
    chown -R clamav:clamav /var/run/clamav
    if [ -e "/lib/systemd/system/clamav-daemon.service" ]; then
        exec_pre1='ExecStartPre=-/bin/mkdir -p /var/run/clamav'
        exec_pre2='ExecStartPre=-/bin/chown -R clamav:clamav /var/run/clamav'
        sed -i "s|\[Service\]/|[Service]\n$exec_pre1\n$exec_pre2|g" \
            /lib/systemd/system/clamav-daemon.service
        systemctl daemon-reload
    fi
    service clamav-daemon start
    check_result $? "clamav-daeom start failed"
fi


#----------------------------------------------------------#
#                  Configure SpamAssassin                  #
#----------------------------------------------------------#

if [ "$spamd" = 'yes' ]; then
    update-rc.d spamassassin defaults
    sed -i "s/ENABLED=0/ENABLED=1/" /etc/default/spamassassin
    service spamassassin start
    check_result $? "spamassassin start failed"
    unit_files="$(systemctl list-unit-files |grep spamassassin)"
    if [[ "$unit_files" =~ "disabled" ]]; then
        systemctl enable spamassassin
    fi
fi


#----------------------------------------------------------#
#                   Configure RoundCube                    #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ] && [ "$mysql" = 'yes' ]; then
    if [ "$apache" = 'yes' ]; then
        cp -f $vestacp/roundcube/apache.conf /etc/roundcube/
        ln -s /etc/roundcube/apache.conf /etc/apache2/conf.d/roundcube.conf
    fi
    cp -f $vestacp/roundcube/main.inc.php /etc/roundcube/
    cp -f  $vestacp/roundcube/db.inc.php /etc/roundcube/
    chmod 640 /etc/roundcube/debian-db-roundcube.php
    chmod 640 /etc/roundcube/config.inc.php
    chown root:www-data /etc/roundcube/debian-db-roundcube.php
    chown root:www-data /etc/roundcube/config.inc.php
    cp -f $vestacp/roundcube/vesta.php \
        /usr/share/roundcube/plugins/password/drivers/
    cp -f $vestacp/roundcube/config.inc.php /etc/roundcube/plugins/password/
    r="$(gen_pass)"
    mysql -e "CREATE DATABASE roundcube"
    mysql -e "GRANT ALL ON roundcube.* 
        TO roundcube@localhost IDENTIFIED BY '$r'"
    sed -i "s/%password%/$r/g" /etc/roundcube/db.inc.php
    sed -i "s/localhost/$servername/g" \
        /etc/roundcube/plugins/password/config.inc.php
    mysql roundcube < /usr/share/dbconfig-common/data/roundcube/install/mysql
    chmod a+r /etc/roundcube/main.inc.php
    if [ "$release" -eq 8 ] || [ "$release" -eq 9 ]; then
        mv -f /etc/roundcube/main.inc.php /etc/roundcube/config.inc.php
        mv -f /etc/roundcube/db.inc.php /etc/roundcube/debian-db-roundcube.php
        chmod 640 /etc/roundcube/debian-db-roundcube.php
        chmod 640 /etc/roundcube/config.inc.php
        chown root:www-data /etc/roundcube/debian-db-roundcube.php
        chown root:www-data /etc/roundcube/config.inc.php
    fi
    if [ "$release" -eq 8 ]; then
        # RoundCube tinyMCE fix
        tinymceFixArchiveURL=$vestacp/roundcube/roundcube-tinymce.tar.gz
        tinymceParentFolder=/usr/share/roundcube/program/js
        tinymceFolder=$tinymceParentFolder/tinymce
        tinymceBadJS=$tinymceFolder/tiny_mce.js
        tinymceFixArchive=$tinymceParentFolder/roundcube-tinymce.tar.gz
        if [[ -L "$tinymceFolder" && -d "$tinymceFolder" ]]; then
            if [ -f "$tinymceBadJS" ]; then
                wget $tinymceFixArchiveURL -O $tinymceFixArchive
                if [[ -f "$tinymceFixArchive" && -s "$tinymceFixArchive" ]]
                then
                    rm $tinymceFolder
                    tar -xzf $tinymceFixArchive -C $tinymceParentFolder
                    rm $tinymceFixArchive
                    chown -R root:root $tinymceFolder
                else
                    echo -n "File roundcube-tinymce.tar.gz is not downloaded,"
                    echo "RoundCube tinyMCE fix is not applied"
                    rm $tinymceFixArchive
                fi
            fi
        fi

    fi
fi


#----------------------------------------------------------#
#                    Configure Fail2Ban                    #
#----------------------------------------------------------#

if [ "$fail2ban" = 'yes' ]; then
    cp -rf $vestacp/fail2ban /etc/
    if [ "$dovecot" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n dovecot-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$exim" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n exim-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$vsftpd" = 'yes' ]; then
        #Create vsftpd Log File
        if [ ! -f "/var/log/vsftpd.log" ]; then
            touch /var/log/vsftpd.log
        fi
        fline=$(cat /etc/fail2ban/jail.local |grep -n vsftpd-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/false/true/" /etc/fail2ban/jail.local
    fi 
    update-rc.d fail2ban defaults
    service fail2ban start
    check_result $? "fail2ban start failed"
fi


#----------------------------------------------------------#
#                   Configure Admin User                   #
#----------------------------------------------------------#

# Deleting old admin user
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ "$force" = 'yes' ]; then
    chattr -i /home/admin/conf > /dev/null 2>&1
    userdel -f admin >/dev/null 2>&1
    chattr -i /home/admin/conf >/dev/null 2>&1
    mv -f /home/admin  $vst_backups/home/ >/dev/null 2>&1
    rm -f /tmp/sess_* >/dev/null 2>&1
fi
if [ ! -z "$(grep ^admin: /etc/group)" ]; then
    groupdel admin > /dev/null 2>&1
fi

# Adding vesta account
$VESTA/bin/v-add-user admin $vpass $email default System Administrator
check_result $? "can't create admin user"
$VESTA/bin/v-change-user-shell admin bash
$VESTA/bin/v-change-user-language admin $lang

# RoundCube permissions fix
if [ "$exim" = 'yes' ] && [ "$mysql" = 'yes' ]; then
    if [ ! -d "/var/log/roundcube" ]; then
        mkdir /var/log/roundcube
    fi
    chown admin:admin /var/log/roundcube
fi

# Configuring system ips
$VESTA/bin/v-update-sys-ip

# Get main ip
ip=$(ip addr|grep 'inet '|grep global|head -n1|awk '{print $2}'|cut -f1 -d/)
local_ip=$ip

# Firewall configuration
if [ "$iptables" = 'yes' ]; then
    $VESTA/bin/v-update-firewall
fi

# Get public ip
pub_ip=$(curl -s vestacp.com/what-is-my-ip/)

if [ ! -z "$pub_ip" ] && [ "$pub_ip" != "$ip" ]; then
    $VESTA/bin/v-change-sys-ip-nat $ip $pub_ip
    ip=$pub_ip
fi

# Configuring libapache2-mod-remoteip
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    cd /etc/apache2/mods-available
    echo "<IfModule mod_remoteip.c>" > remoteip.conf
    echo "  RemoteIPHeader X-Real-IP" >> remoteip.conf
    if [ "$local_ip" != "127.0.0.1" ] && [ "$pub_ip" != "127.0.0.1" ]; then
        echo "  RemoteIPInternalProxy 127.0.0.1" >> remoteip.conf
    fi
    if [ ! -z "$local_ip" ] && [ "$local_ip" != "$pub_ip" ]; then
        echo "  RemoteIPInternalProxy $local_ip" >> remoteip.conf
    fi
    if [ ! -z "$pub_ip" ]; then
        echo "  RemoteIPInternalProxy $pub_ip" >> remoteip.conf
    fi
    echo "</IfModule>" >> remoteip.conf
    sed -i "s/LogFormat \"%h/LogFormat \"%a/g" /etc/apache2/apache2.conf
    a2enmod remoteip
    service apache2 restart
fi

# Configuring mysql host
if [ "$mysql" = 'yes' ]; then
    $VESTA/bin/v-add-database-host mysql localhost root $mpass
    $VESTA/bin/v-add-database admin default default $(gen_pass) mysql
fi

# Configuring pgsql host
if [ "$postgresql" = 'yes' ]; then
    $VESTA/bin/v-add-database-host pgsql localhost postgres $ppass
    $VESTA/bin/v-add-database admin db db $(gen_pass) pgsql
fi

# Adding default domain
$VESTA/bin/v-add-domain admin $servername
check_result $? "can't create $servername domain"

# Adding cron jobs
command="sudo $VESTA/bin/v-update-sys-queue disk"
$VESTA/bin/v-add-cron-job 'admin' '15' '02' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue traffic"
$VESTA/bin/v-add-cron-job 'admin' '10' '00' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue webstats"
$VESTA/bin/v-add-cron-job 'admin' '30' '03' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue backup"
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-backup-users"
$VESTA/bin/v-add-cron-job 'admin' '10' '05' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-user-stats"
$VESTA/bin/v-add-cron-job 'admin' '20' '00' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-rrd"
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
service cron restart

# Building inititall rrd images
$VESTA/bin/v-update-sys-rrd

# Enabling file system quota
if [ "$quota" = 'yes' ]; then
    $VESTA/bin/v-add-sys-quota
fi

# Enabling softaculous plugin
if [ "$softaculous" = 'yes' ]; then
    $VESTA/bin/v-add-vesta-softaculous
fi

# Starting vesta service
update-rc.d vesta defaults
service vesta start
check_result $? "vesta start failed"
chown admin:admin $VESTA/data/sessions

# Adding notifications
$VESTA/upd/add_notifications.sh

# Adding cronjob for autoupdates
$VESTA/bin/v-add-cron-vesta-autoupdate


#----------------------------------------------------------#
#                   Vesta Access Info                      #
#----------------------------------------------------------#

# Comparing hostname and ip
host_ip=$(host $servername| head -n 1 | awk '{print $NF}')
if [ "$host_ip" = "$ip" ]; then
    ip="$servername"
fi

# Sending notification to admin email
echo -e "Congratulations, you have just successfully installed \
Vesta Control Panel

    https://$ip:8083
    username: admin
    password: $vpass

We hope that you enjoy your installation of Vesta. Please \
feel free to contact us anytime if you have any questions.
Thank you.

--
Sincerely yours
vestacp.com team
" > $tmpfile

send_mail="$VESTA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Vesta Control Panel" $email

# Congrats
echo '======================================================='
echo
echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|   '
echo ' _|      _|  _|        _|            _|      _|    _| '
echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_| '
echo '   _|  _|    _|              _|      _|      _|    _| '
echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _| '
echo
echo
cat $tmpfile
rm -f $tmpfile

# EOF
