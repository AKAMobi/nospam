#!/bin/sh

chmod g+s service/*
chmod g+s service/*/log

chmod o+t service/*
chmod o+t service/*/log

chown qmaill service/{smtpd,ismtpd,pop3d,qmail}/log/{main,status}
chown nospam service/nsd/log/{main,status}
chown nospam service/gad/log/{main,status}
chown named service/named/log/main

chmod +x service/*/run
chmod +x service/*/log/run
chmod +x etc/cron.hourly/*

ln -s /home/NoSPAM/bin/NoSPAM etc/rc.d/rc3.d/S11NoSPAM_start_System
ln -s /var/qmail/control/servercert.pem var/qmail/control/clientcert.pem
chown qmaild.qmail var/qmail/control/*.pem
