#!/bin/sh

chmod g+s service/*
chmod g+s service/*/log

chmod o+t service/*
chmod o+t service/*/log

chown qmaill service/*/log/{main,status}

chmod +x service/*/run

ln -s /home/NoSPAM/bin/NoSPAM etc/rc.d/rc3.d/S11NoSPAM_start_System
