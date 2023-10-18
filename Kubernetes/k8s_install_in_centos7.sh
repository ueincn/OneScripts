#!/bin/bash

#Program
#   Kubernetes (All In One) Install Scripts
#History
#   2023   Ueincn  Release
#Platform
#   CentOS 7.9.2009

#判断权限
if [ $UID -gt 0 ]; then
    echo ""
    echo "[ $(tput setaf 1)!! Please use sudo permissions or switch root to run the script !! $(tput sgr0)]"
    echo ""
fi