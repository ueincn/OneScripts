#!/bin/bash

#判断权限
if [ $UID -gt 0 ]; then
    echo ""
    echo "[ $(tput setaf 1)!! Please use sudo permissions or switch root to run the script !! $(tput sgr0)]"
    echo ""
fi