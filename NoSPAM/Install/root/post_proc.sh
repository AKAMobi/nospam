#!/bin/sh

chmod g+s service/*
chmod g+s service/*/log

chmod o+t service/*
chmod o+t service/*/log

chown qmaill service/*/log/{main,status}
