#!/usr/bin/bash

# Check if script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

#install dependencies and upgrade
sudo add-apt-repository -y ppa:ondrej/php 
sudo add-apt-repository -y universe 
sudo apt update -y 
sudo apt install -y libedit-dev nodejs npm libapache2-mod-php7.4 php7.4 php7.4-{mysql,cli,common,imap,ldap,xml,fpm,curl,mbstring,zip,gd,gettext,xml,json,snmp} lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev build-essential libjansson-dev libxml2-dev  uuid-dev mariadb-server apache2
sudo apt upgrade -y 

#download and extract asterisk archive 
cd /usr/src/
sudo curl -O http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz 
sudo tar -xvf asterisk-18-current.tar.gz

#Set compile flags and compile asterisk
cd /usr/src/asterisk-18.*/
sudo contrib/scripts/install_prereq install 
sudo ./configure 
menuselect/menuselect --enable app_dial --enable app_stack --enable app_voicemail --enable chan_bridge --enable chan_sip --enable codec_alaw --enable codec_dahdi --enable codec_ulaw --enable res_adsi --enable res_rtp_asterisk --enable app_authenticate --enable app_cdr --enable app_channelredirect --enable app_chanspy --enable app_controlplayback --enable app_dictate --enable app_directed_pickup --enable app_directory --enable app_disa --enable app_dumpchan --enable app_fax --enable app_externalivr --enable app_exec --enable app_echo --enable app_flash --enable app_followme --enable app_originate --enable app_mixmonitor --enable app_milliwatt --enable app_jack --enable app_meetme --enable app_page --enable app_plaback --enable app_playtones --enable app_read --enable app_readexten --enable app_record --enable app_sayunixtime --enable app_senddtmf --enable app_skel --enable app_speech_utils --enable app_softhangup --enable app_talkdetect --enable app_system --enable app_transfer --enable app_userevent --enable app_verbose --enable app_waitforsilence --enable app_waituntil --enable app_while --enable cdr_adaptive_odbc --enable cdr_manager --enable cdr_custom --enable cdr_pgsql --enable cdr_syslog --enable cel_pgsql --enable cel_odbc --enable cel_manager --enable cel_custom --enable cel_sqlite3_custom --enable chan_agent --enable chan_alsa --enable chan_oss --enable chan_multicast_rtp --enable chan_local --enable chan_iax2 --enable chan_dahdi --enable codec_a_mu --enable codec_g722 --enable codec_gsm --enable format_g729 --enable format_vox --enable format_wav --enable format_siren14 --enable func_blacklist --enable func_audiohookinherit --enable func_aes --enable func_cdr --enable func_callerid --enable func_aes --enable func_iconv --enable func_global --enable func_extstate --enable func_env --enable func_enum --enable func_dialplan --enable func_dialgroup --enable pbx_dundi --enable pbx_config --enable pbx_lua --enable pbx_realtime --enable pbx_spool --enable res_config_mysql menuselect.makeopts
sudo make
sudo make install 
sudo make samples
sudo make config
sudo ldconfig 

#add asterisk user
sudo groupadd asterisk 
sudo useradd -r -d /var/lib/asterisk -g asterisk asterisk 
sudo usermod -aG audio,dialout asterisk
sudo chown -R asterisk.asterisk /etc/asterisk 
sudo chown -R asterisk.asterisk /var/{lib,log,spool}/asterisk 
sudo chown -R asterisk.asterisk /usr/lib/asterisk 

#configure /etc/default/asterisk and asterisk.conf
sudo sed '/#AST_USER="asterisk"/s/^#//' -i /etc/default/asterisk 
sudo sed '/#AST_GROUP="asterisk"/s/^#//' -i /etc/default/asterisk 
sudo sed '/runuser = asterisk ; The user to run as./s/^#//' -i /etc/asterisk/asterisk.conf 
sudo sed '/rungroup = asterisk ; The group to run as./s/^#//' -i /etc/asterisk/asterisk.conf 

#restart asterisk daemon
sudo systemctl enable asterisk 
sudo systemctl start asterisk

#configure apache config and store default
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig 
sudo sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf 
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf 
sudo rm -f /var/www/html/index.html 
sudo unlink /etc/apache2/sites-enabled/000-default.conf 
sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini 
sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/cli/php.ini 
sudo sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini 

#download FreePBX 16 archive
cd /usr/src/
sudo wget http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
sudo tar xzf ./freepbx-16.0-latest.tgz 
cd /usr/src/freepbx/
sudo ./start_asterisk start 
sudo ./install -n 
sudo fwconsole ma disablerepo commercial 
sudo fwconsole ma installall 
sudo fwconsole ma delete firewall 
sudo fwconsole reload 
sudo fwconsole restart 

#finish apache config
sudo a2enmod rewrite 
sudo systemctl restart apache2 

#open ports for ssh http https and SIP
#!/bin/bash

# Enable ufw with automatic 'yes' response
yes | sudo ufw enable
sudo ufw allow 10000:20000
sudo ufw allow 5060
sudo ufw allow 5061
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow smtp
sudo apt update

#install and configure fail2ban
sudo apt -y install fail2ban 
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/\/var\/log\/asterisk\/messages/\/var\/log\/asterisk\/full/g' /etc/fail2ban/jail.local
sudo sed -i '/\[asterisk\]/ { n; s/.*/enabled = true/ }' /etc/fail2ban/jail.local
sudo systemctl enable fail2ban 
sudo systemctl start fail2ban 