#!/bin/sh 
#sar -d 1 3 | tail -1 | awk '{print $4"\n"$3}'
#sar -b 1 2 | tail -1 | awk '{print $5 "\n" $6}'
vmstat 1 2 | tail -1 | awk '{print $10 "\n" $11}'
