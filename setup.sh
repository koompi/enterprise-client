#!/bin/bash
clear 

##.................color...................
RED='\033[0;31m'
GREEN='\e[32m'
YELLOW='\033[1;33m'
BLUE='\033[1;32m'
NC='\033[0m'



createlog(){

    NOW=$(date +"%m-%d-%Y-%T")
    mkdir -p /klab/
    mkdir -p /klab/samba
    mkdir -p /klab/samba/log
    LOG="/klab/samba/log/clientlog-$NOW"

    rm -rf $LOG
}

##.................read input..................
readinput(){
# read -p "Domain: " VAL1
# read -p "IP Address: " IPADDRESS

    hostname=$(TERM=ansi whiptail --clear --title "[ Hostname Selection ]"  --backtitle "Samba Active Directory Domain Controller" \
    --nocancel --ok-button Submit --inputbox \
    "\nPlease enter a suitable new hostname for the client to join the active directory server.\nExample:  adclient-01\n" 10 80 \
    3>&1 1>&2 2>&3)

    REALM=$(TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" \
    --title "[ Realm Selection ]" --nocancel --ok-button Submit  --inputbox "                                       
Please enter the FULL REALM NAME of the active directory server. Example:

        Server Name     =   adlab
        Domain Name     =   koompilab
        Realm Name      =   koompilab.org

----------------------------------------------------------------------------
        Full Realm Name =   adlab.koompilab.org" 15 80 3>&1 1>&2 2>&3) 
    
    server_hostname=$(echo $REALM |awk -F'.' '{printf $1}')
    secondlvl_domain=$(echo $REALM |awk -F'.' '{printf $NF}')

    DOMAIN=${REALM//"$server_hostname."}
    DOMAIN=${DOMAIN//".$secondlvl_domain"}
    REALM="$DOMAIN.$secondlvl_domain"

    REALM=${REALM^^}
    DOMAIN=${DOMAIN^^}


    while true;
    do
        IPADDRESS=$(TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" \
        --title "[ IP of Domain ]" --nocancel --ok-button Submit --inputbox \
        "\nPlease enter the IP of the active directory server\nExample:  172.16.1.1\n" 8 80 3>&1 1>&2 2>&3)
        if [[ $IPADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]];
        then
            break
        else
            TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
            "[ IP for Domain ]" --msgbox "Your IP isn't valid. A valid IP should looks like XXX.XXX.XXX.XXX" 10 80
        fi
    done


    while true;
    do
        samba_password=$(TERM=ansi whiptail --clear --title "[ Administrator Password ]" --nocancel --ok-button Submit --passwordbox \
        "\nPlease enter Administrator password for joining domain\n" 10 80 3>&1 1>&2 2>&3)

        samba_password_again=$(TERM=ansi whiptail --clear --title "[ Administrator Password ]" --nocancel --ok-button Submit \
        --passwordbox "\nPlease enter Administrator password again" 10 80  3>&1 1>&2 2>&3)

        if  [[ "$samba_password" != "$samba_password_again" ]];
        then
            TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
            "[ Administrator Password ]" --msgbox "Your password does match. Please retype it again" 10 80

        elif [[ "${#samba_password}" < 8 ]];
        then
                TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
                "[ Administrator Password ]" --msgbox "Your password does not meet the length requirement." 10 80
        else
                break
        fi

    done


# newdomains=$VAL1
# NEWDOMAIN=$(echo "$VAL1" | tr '[:lower:]' '[:upper:]')
# newsubdomains=$(echo "$VAL1" | awk -F'.' '{print $1}')
# NEWSUBDOMAIN=$(echo "$newsubdomains" | tr '[:lower:]' '[:upper:]')
}


check_root(){
    if [[ $(id -u) != 0 ]];
    then 
        echo -e "${RED}[ FAILED ]${NC} Root Permission Requirement Failed"
        exit;
    fi 
}


sethostname(){

    sudo hostnamectl set-hostname $hostname
    # sudo hostname $hostname
    HOSTNAME=$hostname
}

##....................banner....................
banner(){
    # echo
    # BANNER_NAME=$1
    # echo -e "${YELLOW}[+] ${BANNER_NAME} "
    # echo -e "---------------------------------------------------${NC}"
    echo -e "XXX\n$1\n$2\nXXX"
}

##....................check root user.................

##..........................install package base.......................
install_package_base(){

    for P in $(cat $(pwd)/package/package_x86_64)
    do
        if [[ -n "$(pacman -Qs $P)" ]];
        then 
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $P $NC Installed."
        else 
            sudo pacman -S $P --noconfirm 2>/dev/null
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $P $NC Installed successful."
        fi
    done

}

##...................krb5 rename.......................
krb5(){

    cp $(pwd)/krb5/krb5.conf /etc/
    # grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    # grep -rli domains /etc/krb5.conf | xargs -i@ sed -i s/domains/$newdomains/g @
    # grep -rli subdomain /etc/krb5.conf | xargs -i@ sed -i s/subdomain/$newsubdomains/g @
    grep -rli SRVREALM /etc/krb5.conf | xargs -i@ sed -i s/SRVREALM/"${server_hostname^^}.$REALM"/g @
    grep -rli REALM /etc/krb5.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring krb5..." >> $LOG

}

##..................samba rename...................
samba(){

    sudo cp $(pwd)/samba/* /etc/samba/
    sudo cp $(pwd)/samba/pam_winbind.conf /etc/security/
    echo -e "${GREEN}[ OK ]${NC} copy config."

    grep -rli DOMAIN /etc/samba/smb.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    grep -rli REALM /etc/samba/smb.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli SREALM /etc/samba/smb.conf | xargs -i@ sed -i s/SREALM/${REALM,,}/g @
    grep -rli HOSTNAME /etc/samba/smb.conf | xargs -i@ sed -i s/HOSTNAME/$HOSTNAME/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring samba rename"

}

##.....................pam mount.......................
pam_mount(){
   
    cp $(pwd)/pam_mount/* /etc/security/
    echo -e "${GREEN}[ OK ]${NC} Copy pam_mount configure" 

    grep -rli REALM /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli DOMAIN /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+DOMAIN+${DOMAIN}+g @
    echo -e "${GREEN}[ OK ]${NC} Configure pam_mount"

}
##..................mysmb service..................
mysmb(){
    
    sudo cp $(pwd)/scripts/mysmb /usr/bin/mysmb
    sudo cp $(pwd)/service/mysmb.service /usr/lib/systemd/system/
    sudo chmod +x /usr/bin/mysmb
    echo -e "${GREEN}[ OK ]${NC} Configuring necessary service" 
}

##..................nsswitch..................
nsswitch(){
    
    sudo cp $(pwd)/nsswitch/nsswitch.conf /etc/nsswitch.conf
    echo -e "${GREEN}[ OK ]${NC} Configuring nsswitch" 
}

##..................pam authentication...............
pam(){

    sudo cp $(pwd)/pam.d/* /etc/pam.d/
    echo -e "${GREEN}[ OK ]${NC} Configuring pam.d"
}

##...................resolv..................
resolv(){

    RESOLVCONF_FILE=/etc/resolvconf.conf
    RESOLV_FILE=/etc/resolv.conf
        
    #resolvconf
    cp resolv/resolvconf.conf ${RESOLVCONF_FILE}
    grep -rli REALM ${RESOLVCONF_FILE} | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli NAMESERVER ${RESOLVCONF_FILE} | xargs -i@ sed -i s+NAMESERVER+${IPADDRESS}+g @
    # echo "name_servers=${IPADDRESS}" >> ${RESOLVCONF_FILE}
    # echo "search_domains=${REALM,,}" >> ${RESOLVCONF_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolvconf"

    #resolv
    echo "search ${REALM,,}" > ${RESOLV_FILE}
    echo "nameserver ${IPADDRESS}" >> ${RESOLV_FILE}
    echo "nameserver 8.8.8.8" >> ${RESOLV_FILE}
    echo "nameserver 8.8.4.4" >> ${RESOLV_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolv.conf"

}

##........................stop service...................
stopservice(){

    sudo systemctl enable smb nmb winbind mysmb
    sudo systemctl stop smb nmb winbind mysmb
    echo -e "${GREEN}[ OK ]${NC} Stoped service"

}

##.....................join domain.......................
joindomain(){

    # domain=$(echo $VAL1 | tr '[:lower:]' '[:upper:]')
    echo "$samba_password" | kinit administrator@${REALM}
    echo "$samba_password" | sudo net join -U Administrator@$REALM
    echo -e "${GREEN}[ OK ]${NC} Join domain successful"
}

##.......................start service.....................
startservice(){

    sudo systemctl start smb nmb winbind
    echo -e "${GREEN}[ OK ]${NC} Started service" 
    echo -e "${GREEN}[ OK ]${NC} Installation Completed" 
}

check_root
createlog
readinput

{

    banner "5" "Setting Hostname"
    sethostname >> $LOG

    banner "10" "Installing necessary packages."
    install_package_base >> $LOG

    banner "25" "Configuring Keberos Network Authenticator"
    krb5 >> $LOG

    banner "30" "Configuring Samba Active Directory Domain Controller Server"
    samba >> $LOG

    banner "50" "Configuring Auto-mount Storage Drives Settings"
    pam_mount >> $LOG

    banner "55" "Configuring Samba Helper Service"
    mysmb >> $LOG

    banner "65" "Configuring Name Service Swtich"
    nsswitch >> $LOG

    banner "70" "Configuring Pluggable Authentication Modules For Linux"
    pam >> $LOG

    banner "75" "Configuring Dynamic Name Service Resolver"
    resolv >> $LOG

    banner "80" "Stopping Samba Related Service"
    stopservice &>> $LOG

    banner "90" "Joining $REALM Domain"
    joindomain >> $LOG

    banner "100" "Starting Samba Related Service"
    startservice &>> $LOG

} | whiptail --clear --title "[ KOOMPI AD Server ]" --gauge "Please wait while installing" 10 100 0