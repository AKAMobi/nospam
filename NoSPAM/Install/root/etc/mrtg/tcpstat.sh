#!/bin/sh

netstat -na | grep ESTABLISHED | wc -l | awk '{print $1}'
netstat -na | grep TIME | wc -l | awk '{print $1}'
