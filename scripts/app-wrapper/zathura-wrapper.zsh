#!/bin/zsh


# TODO: convert into ruby script and add to config if it should be started
#       normally or with highdpi

unset GDK_DPI_SCALE
unset GDK_SCALE

exec /usr/bin/zathura "$@"
