#!/bin/zsh


# TODO: convert into ruby script and add to config if it should be started
#       normally or with highdpi

QT_AUTO_SCREEN_SCALE_FACTOR= QT_SCREEN_SCALE_FACTORS= QT_SCALE_FACTOR= exec /usr/bin/VirtualBox "$@"
