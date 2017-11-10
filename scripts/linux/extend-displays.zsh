#!/bin/zsh
# extend non-HiDPI external display on DP* above HiDPI internal display eDP*
# see also https://wiki.archlinux.org/index.php/HiDPI
# you may run into https://bugs.freedesktop.org/show_bug.cgi?id=39949
#                  https://bugs.launchpad.net/ubuntu/+source/xorg-server/+bug/883319

_pos_of_lowdpi_display="above" # choose from above, below, right, left.

_hidpi_display_name="eDP1" #`xrandr --current | sed 's/^\(.*\) connected.*$/\1/p;d' | grep -v ^eDP | head -n 1`
_lowdpi_display_name="DP1" #`xrandr --current | sed 's/^\(.*\) connected.*$/\1/p;d' | grep -v ^DP | head -n 1`

_lowdpi_display_width=`xrandr | sed 's/^'"${_lowdpi_display_name}"' [^0-9]* \([0-9]\+\)x.*$/\1/p;d'`
_lowdpi_display_height=`xrandr | sed 's/^'"${_lowdpi_display_name}"' [^0-9]* [0-9]\+x\([0-9]\+\).*$/\1/p;d'`
_hidpi_display_width=`xrandr | sed 's/^'"${_hidpi_display_name}"' [^0-9]* \([0-9]\+\)x.*$/\1/p;d'`
_hidpi_display_height=`xrandr | sed 's/^'"${_hidpi_display_name}"' [^0-9]* [0-9]\+x\([0-9]\+\).*$/\1/p;d'`

_offset_width=`echo $(( (${_hidpi_display_width}-(${_lowdpi_display_width}*2))/2 )) | sed 's/^-//'`
_offset_height=`echo $(( ${_lowdpi_display_height}*2 ))`

case "${_pos_of_lowdpi_display}" in
  above)
    xrandr --output "${_hidpi_display_name}" --auto --scale 1x1 \
           --pos "${_offset_width}x${_offset_height}" \
           --output "${_lowdpi_display_name}" --auto --scale 2x2 \
           --pos 0x0
    ;;
  *)
    echo "Invalid position."
    exit -1
    ;;
esac


# xrandr --output eDP1 --primary --mode 2880x1620 --pos 0x0 --rotate normal \
# --output DP2-1 --mode 1680x1050 --pos 2880x0 --scale 2x2 --panning 3360x2100 --right-of eDP1 --rotate normal
#
# ~
# xrandr --output DP2-1 --off
#
# ~
# xrandr --output eDP1 --primary --mode 2880x1620 --pos 0x0 --rotate normal \
# --output DP2-1 --mode 1680x1050 --pos 2880x0 --scale 2x2 --right-of eDP1 --rotate normal
