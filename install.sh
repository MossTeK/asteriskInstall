#!/usr/bin/bash
touch installLog.txt
installLog="$(dirname "$(readlink -f "$0")")/installLog.txt"

# Check if script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting..." | tee $installLog
    exit 1
fi

#add main function
function main() {
    
    for arg in "$@"; do
        $arg | tee $installLog
        if $? >> $installLog; then
           echo "ran $arg"
        else
            echo "unable to run $arg"
    done

}

function installDependencies() {
    
    #adding ppa's
    add-apt-repository -y ppa:ondrej/php 
    add-apt-repository -y universe 
    apt update -y 
    
    #loop through dependencies to see if they are installed then install if not already
    for arg in "$@"; do
        if ! dpkg -l | grep -o "$arg"; then
            apt -y install "$arg"
        else   
            echo "package:$arg is already installed"
        fi
    done
    #upgrade once done
    apt upgrade -y
}

function installAsterisk() {
    #download and extract asterisk archive 
    cd /usr/src/
    curl -O http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz 
    tar -xvf asterisk-18-current.tar.gz

    #move into asterisk directory, run install_prereq & ./configure. Declare asterisk modules
    cd /usr/src/asterisk-18.*/
    contrib/scripts/install_prereq install 
    menuselect/menuselect --enable app_dial --enable app_stack --enable app_voicemail --enable chan_bridge --enable chan_sip --enable codec_alaw --enable codec_dahdi --enable codec_ulaw --enable res_adsi --enable res_rtp_asterisk --enable app_authenticate --enable app_cdr --enable app_channelredirect --enable app_chanspy --enable app_controlplayback --enable app_dictate --enable app_directed_pickup --enable app_directory --enable app_disa --enable app_dumpchan --enable app_fax --enable app_externalivr --enable app_exec --enable app_echo --enable app_flash --enable app_followme --enable app_originate --enable app_mixmonitor --enable app_milliwatt --enable app_jack --enable app_meetme --enable app_page --enable app_plaback --enable app_playtones --enable app_read --enable app_readexten --enable app_record --enable app_sayunixtime --enable app_senddtmf --enable app_skel --enable app_speech_utils --enable app_softhangup --enable app_talkdetect --enable app_system --enable app_transfer --enable app_userevent --enable app_verbose --enable app_waitforsilence --enable app_waituntil --enable app_while --enable cdr_adaptive_odbc --enable cdr_manager --enable cdr_custom --enable cdr_pgsql --enable cdr_syslog --enable cel_pgsql --enable cel_odbc --enable cel_manager --enable cel_custom --enable cel_sqlite3_custom --enable chan_agent --enable chan_alsa --enable chan_oss --enable chan_multicast_rtp --enable chan_local --enable chan_iax2 --enable chan_dahdi --enable codec_a_mu --enable codec_g722 --enable codec_gsm --enable format_g729 --enable format_vox --enable format_wav --enable format_siren14 --enable func_blacklist --enable func_audiohookinherit --enable func_aes --enable func_cdr --enable func_callerid --enable func_aes --enable func_iconv --enable func_global --enable func_extstate --enable func_env --enable func_enum --enable func_dialplan --enable func_dialgroup --enable pbx_dundi --enable pbx_config --enable pbx_lua --enable pbx_realtime --enable pbx_spool --enable res_config_mysql menuselect.makeopts
    ./configure 

    #make commands
    commands=("make" "make install" "make samples" "make config" "ldconfig")

    for arg in "$commands"; do
        #run make commands and check status
        $arg
        if $?; then
            echo "Error: Command '$arg' failed with exit code $?." | tee ./install.log
            exit $status
        fi
    done

    #add asterisk user
    groupadd asterisk 
    useradd -r -d /var/lib/asterisk -g asterisk asterisk 
    usermod -aG audio,dialout asterisk

    #set directory permissions for asterisk
    chown -R asterisk.asterisk /etc/asterisk 
    chown -R asterisk.asterisk /var/{lib,log,spool}/asterisk 
    chown -R asterisk.asterisk /usr/lib/asterisk 

    #configure /etc/default/asterisk and asterisk.conf
    sed '/#AST_USER="asterisk"/s/^#//' -i /etc/default/asterisk 
    sed '/#AST_GROUP="asterisk"/s/^#//' -i /etc/default/asterisk 
    sed '/runuser = asterisk ; The user to run as./s/^#//' -i /etc/asterisk/asterisk.conf 
    sed '/rungroup = asterisk ; The group to run as./s/^#//' -i /etc/asterisk/asterisk.conf 

    #restart asterisk daemon
    systemctl enable asterisk 
    systemctl start asterisk

    #make sure it was added succesfully
    if $(id -nG asterisk | grep -w '^audio$') -eq 1 && $(id -nG asterisk | grep -w '^dialout$') -eq 1; then
        echo "The asterisk user is in both the audio and dialout groups."
    else
        echo "The asterisk user is not in both the audio and dialout groups."
    fi

}

function installApache() {
    #configure apache config and store default
    cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig 
    sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf 
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf 
    rm -f /var/www/html/index.html 
    unlink /etc/apache2/sites-enabled/000-default.conf 
    sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini 
    sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/cli/php.ini 
    sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini 
}

function installFreePBX() {
    #download FreePBX 16 archive
    cd /usr/src/
    wget http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
    tar xzf ./freepbx-16.0-latest.tgz 
    cd /usr/src/freepbx/
    ./start_asterisk start 
    ./install -n 
    fwconsole ma disablerepo commercial 
    fwconsole ma installall 
    fwconsole ma delete firewall 
    fwconsole reload 
    fwconsole restart 

    #write to apache and reload
    a2enmod rewrite 
    systemctl restart apache2 
}

function configureNetwork() {
    # Enable ufw
    yes | ufw enable
    ufw allow 10000:20000
    ufw allow 5060
    ufw allow 5061
    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw allow smtp

    #install and configure fail2ban
    apt update
    apt -y install fail2ban 
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i 's/\/var\/log\/asterisk\/messages/\/var\/log\/asterisk\/full/g' /etc/fail2ban/jail.local
    sed -i '/\[asterisk\]/ { n; s/.*/enabled = true/ }' /etc/fail2ban/jail.local
    systemctl enable fail2ban 
    systemctl start fail2ban 
}

installDependencies "libedit-dev" "nodejs" "npm" "libapache2-mod-php7.4" "php7.4" "php7.4-mysql" "php7.4-cli" "php7.4-common" "php7.4-imap" "php7.4-ldap" "php7.4-xml" "php7.4-fpm" "php7.4-curl" "php7.4-mbstring" "php7.4-zip" "php7.4-gd" "php7.4-gettext" "php7.4-xml" "php7.4-json" "php7.4-snmp" "lsb-release" "ca-certificates" "apt-transport-https" "software-properties-common" "gnupg2" "git" "curl" "wget" "libnewt-dev" "libssl-dev" "libncurses5-dev" "subversion" "libsqlite3-dev" "build-essential" "libjansson-dev" "libxml2-dev" "uuid-dev" "mariadb-server" "apache2" | tee $installLog
main "installAsterisk" "installApache" "installFreePBX" "configureNetwork"