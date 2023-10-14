#!/bin/bash

if [ $UID -eq 0 ]; then
    Main
else
    echo ""
    echo "[ $(tput setaf 1)!! Please use sudo permissions or switch root to run the script !! $(tput sgr0)]"
    echo ""
fi