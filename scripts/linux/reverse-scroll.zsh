#!/usr/bin/env zsh


_pointers_ids=($(                      \
    xinput list                        \
  | grep -E "slave.*pointer"           \
  | grep -vi "bcm5974"                 \
  | grep -vi xtest                     \
  | grep -vi keyboard                  \
  | sed -e 's/^.*id=//' -e 's/\s.*$//' \
  | tr '\n' ' '                        \
  ))

for _pointer_id in ${_pointers_ids[@]}; do
  _pointer_reversed_buttons=$(             \
      xinput get-button-map ${_pointer_id} \
    | tr ' 5' ' %'                         \
    | tr ' 4' ' 5'                         \
    | tr ' %' ' 4'                         \
    | tr '\n' ' '                          \
    )

  echo                                                  \
    "Reversing scroll for pointer \`${_pointer_id}\`: " \
    "\`$(xinput get-button-map ${_pointer_id})\` -> "   \
    "\`${_pointer_reversed_buttons}\`"

  echo ${_pointer_id} ${_pointer_reversed_buttons} | xargs xinput set-button-map
done


# vim: set filetype=zsh :
