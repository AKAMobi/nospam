#!/bin/sh

tail -100 /service/smtpd/log/main/current  | grep status | awk '{print $4}' | grep / | awk -F/ '{print $1}' | tail -1
ps ax | grep qns_loader | wc -l | awk '{print $1}' 
