#!/bin/sh

chmod g+s service/*
chmod g+s service/*/log

chmod o+t service/*
chmod o+t service/*/log

chown qmaill service/{smtpd,ismtpd,pop3d,qmail}/log/{main,status}
chown nospam service/{nsd,gad,pop3s,pyzor,dcc}/log/{main,status}
#chown nospam service/gad/log/{main,status}
chown named service/named/log/main

chmod +x service/*/run
chmod +x service/*/log/run
chmod +x etc/cron.hourly/*
chmod 755 etc/mrtg/*.sh
chmod 755 usr/bin/*

ln -s /usr/etc/mail etc/mail
ln -s /home/NoSPAM/bin/NoSPAM etc/rc.d/rc3.d/S11NoSPAM_start_System
ln -s /var/qmail/control/servercert.pem var/qmail/control/clientcert.pem
ln -s /var/qmail/bin/sendmail usr/bin/sendmail

chown qmaild.qmail var/qmail/control/*.pem
chmod 700 var/qmail/control/*.pem

chmod 755 home/wmail -R
