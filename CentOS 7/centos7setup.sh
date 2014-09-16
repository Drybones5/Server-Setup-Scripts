#! /bin/bash

if [[ $UID -ne 0 ]]; then sudo "$0"; exit 0; fi
echo 'Now going to server setup, here we go...'
echo '------------------------------------'

read -p "Run the update script and add EPEL Repo? [yn]" answer
if [[ $answer = y ]] ; then
  wget http://dl.fedoraproject.org/pub/epel/beta/7/x86_64/epel-release-7-0.2.noarch.rpm
  ls *.rpm
  yum -y install epel-release-7-0.2.noarch.rpm
  yum -y update
  echo 'Installing htop...'
  yum -y install htop ;
fi

read -p "Setup LAMP stack? [yn]" answer
if [[ $answer = y ]] ; then
  yum -y update
  yum -y install httpd
  systemctl start httpd.service
  yum -y install mariadb-server mariadb
  ssystemctl start mariadb
  mysql_secure_installation
  yum -y install php php-mysql
  yum -y install php-*
  systemctl enable httpd.service
  systemctl enable mariadb.service ;
fi

read -p "Change host file contents? [yn]" answer
if [[ $answer = y ]] ; then
  read -p "Please enter the desired Static IP Address for the server on LAN: " ipaddressinput
  read -p "Please neter your desired domain name for the server: " domainnameinput
  read -p "Please neter your desired name for the server: " servernameinput
echo "127.0.0.1   localhost" > /etc/hosts
echo "127.0.1.1 	$servernameinput.$domainnameinput.local 	$servernameinput" >> /etc/hosts
echo "$ipaddressinput	$servernameinput.$domainnameinput.local 	$servernameinput" >> /etc/hosts
echo "$servernameinput.$domainnameinput.local" > /etc/hostname
echo "Server name has been set to:"
hostname -s
echo "Server full hostname has been set to:"
hostname -f
echo "Server is currently set for this network config:"
ifconfig
fi

read -p "Add VNC server? [yn]" answer
if [[ $answer = y ]] ; then
	yum -y groupinstall "Desktop" "Desktop Platform" "X Window System" "Fonts"
	yum -y install gnome-core xfce4 firefox
	yum -y install tigervnc-server
	service vncserver start
	service vncserver stop
	chkconfig vncserver on
	wget http://pkgs.repoforge.org/x11vnc/x11vnc-0.9.13-1.el7.rf.x86_64.rpm
	ls *.rpm
    yum -y install x11vnc-0.9.13-1.el7.rf.x86_64.rpm
    mkdir /root/.vnc/
    x11vnc -storepasswd /root/.vnc/passwd
    vncpassword
    startx
    service vncserver start
	systemcl enable vncserver.service
fi

read -p "Configure a email SSMTP? [yn]" answer
if [[ $answer = y ]] ; then
	echo "Removing sendmail if installed"
yum -y remove sendmail
echo [fedora_repo] >> /etc/yum.repos.d/fedora_repo.repo #allow yum access to the fedora repo
echo name=fedora_repo >> /etc/yum.repos.d/fedora_repo.repo
echo baseurl=http://download1.fedora.redhat.com/pub/epel/\$releasever/\$basearch/ >> /etc/yum.repos.d/fedora_repo.repo
echo enabled=1 >> /etc/yum.repos.d/fedora_repo.repo
echo skip_if_unavailable=1 >> /etc/yum.repos.d/fedora_repo.repo
echo gpgcheck=0 >> /etc/yum.repos.d/fedora_repo.repo
echo "Installing ssmtp"
yum -y install ssmtp
sed 's/^enabled=1/enabled=0/' -i /etc/yum.repos.d/fedora_repo.repo #disable fedora repo
  read -p "Please enter Gmail Username: " gmailuser
  read -p "Please enter Gmail Domain: " gmaildomain
  read -p "Please enter Gmail Password: " gmailpass
  read -p "Please enter Server From Name: " serverfrom
  read -p "Please enter Server From Email Domain: " serverdomain
echo "Saving config of sstmp"
echo "root=$gmailuser@$gmaildomain.com" > /etc/ssmtp/ssmtp.conf
echo "mailhub=smtp.gmail.com:587" >> /etc/ssmtp/ssmtp.conf
echo "hostname=$gmailuser@$gmaildomain.com" >> /etc/ssmtp/ssmtp.conf
echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf
echo "AuthUser=$gmailuser" >> /etc/ssmtp/ssmtp.conf
echo "AuthPass=$gmailpass" >> /etc/ssmtp/ssmtp.conf
echo "FromLineOverride=yes" >> /etc/ssmtp/ssmtp.conf
echo "Securing the file"
chmod 640 /etc/ssmtp/ssmtp.conf
chown root:mail /etc/ssmtp/ssmtp.conf
echo "Changing default from field"
echo "root:$serverfrom@$serverdomain:smtp.gmail.com" > /etc/ssmtp/revaliases
echo "SENDING A TEST EMAIL... NOW"
echo "Test message from CentOS server using ssmtp" | sudo ssmtp -vvv $gmailuser@$gmaildomain
fi

read -p "Configure a RAID Array? [yn]" answer
if [[ $answer = y ]] ; then
  fdisk -l
  read -p "Drive 1: " drive1
  read -p "Drive 2: " drive2
  read -p "Drive 3: " drive3
  read -p "Drive 4: " drive4
mdadm --create /dev/md0 --chunk=256 --level=10 -p f2 --raid-devices=4 /dev/$device1 /dev/$device2 /dev/$device3 /dev/$device4 --verbose
echo "Configuring mdadm"
mdadm --detail --scan --verbose > /etc/mdadm.conf
echo "Setting RAID Array to ext4 file system"
mkfs.ext4 /dev/md0
echo "Creating mount point..."
mkdir /media/raid10
echo "Editing fstab"
echo "/dev/md0 /media/raid10/ ext4 defaults 1 2" >> /etc/fstab
echo "Simulating boot..."
mount -a
mount
echo "Please check to see if RAID mounted in the simulation"
echo "Sending a test RAID Array alert email"
mdadm --monitor --scan --test --oneshot
echo "Adding mdadm config for on boot"
echo 'DAEMON_OPTIONS="--syslog --test"' >> /etc/default/mdadm
fi

read -p "Configure SAMBA for the RAID Array? [yn]" answer
if [[ $answer = y ]] ; then
  fdisk -l
  read -p "Set Main Network Drive Share Name: " sambadir
echo "" >> /etc/samba/smb.conf
echo "/media/raid10/$sambadir" >> /etc/samba/smb.conf
echo "valid users = @users" >> /etc/samba/smb.conf
echo "force group = users" >> /etc/samba/smb.conf
echo "create mask = 0660" >> /etc/samba/smb.conf
echo "directory mask = 0771" >> /etc/samba/smb.conf
echo "writable = yes" >> /etc/samba/smb.conf
echo "read only = No" >> /etc/samba/smb.conf
echo "Added share, restarting samba"
systemctl restart smb.service
systemctl restart nmb.service
echo "Adding firewall rule for samba"
firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload
echo "Adding administrator to samba users"
usermod -aG users administrator
echo "Set password for administrator for samba"
smbpasswd -a administrator
fi

read -p "Install and configure Webmin? [yn]" answer
if [[ $answer = y ]] ; then
  wget http://www.webmin.com/download/rpm/webmin-current.rpm
  rpm -U webmin-current.rpm
echo "Webmin installed, please synchronise Samba users and system user in servers, samba windows file sharing, user sync, and select yes to everything and apply"
echo "Create new users in Samba, Users and groups and put them in users group"
fi

read -p "Configure iptables firewall? [yn]" answer
if [[ $answer = y ]] ; then
  read -p "Turn off firewall? [yn]" answer
  if [[ $answer = y ]] ; then
    systemctl stop firewalld.service
  fi
echo "iptables configured"
echo "Use the command iptables -A INPUT -p tcp --dport PORT -j ACCEPT to add more later"
fi


read -p "Install a Dynamic MOTD? [yn]" answer
if [[ $answer = y ]] ; then
  mkdir setupfiles
  cd serverfiles
  wget http://giz.moe/server-scripts/dynmotd/centos-6/dynmotd
  wget http://giz.moe/server-scripts/dynmotd/login
  wget http://giz.moe/server-scripts/dynmotd/profile
  wget http://giz.moe/server-scripts/dynmotd/sshd_config
  wget http://giz.moe/server-scripts/dynmotd/screenfetch
  cp dynmotd /usr/local/bin/
  cp login /etc/pam.d/
  cp profile /etc/
  cp sshd_config /etc/ssh/
  cp sshd_config /etc/ssh/
  mv screenFetch /usr/bin/
  chown root /etc/pam.d/login
  chown root /etc/profile
  chown root /etc/ssh/
  chmod 755 /usr/local/bin/dynmotd
  chmod 644 /etc/pam.d/login
  chmod 644 /etc/profile
  chmod 600 /etc/ssh/sshd_config
  chmod 755 /usr/bin/screenfetch
  systemctl stop sshd
echo "Edit /usr/local/bin/dynmotd to change the MOTD."
echo "Log out and log back in to test the new MOTD"
fi