#!/usr/bin/env zsh


autoload colors && colors

# {{{ Configuration.

_script_name=$(basename "$0")
_default_title="term_$(cat < /dev/urandom |tr -dc 'a-z0-9'|fold -w 8|head -n 1)"
pidof urxvtd
if [[ $? -eq 0 ]]; then
  _urxvt_cmd="urxvtc"
else
  _urxvt_cmd="urxvt"
fi

# }}}

# {{{ Utilities.

usage()
{
  echo -e \
    "usage:\n" \
    "\t${fg[cyan]}${_script_name}${reset_color} " \
    "[${fg[green]}--title${reset_color} ${fg[red]}TITLE${reset_color}]" \
    "[${fg[green]}--cmd${reset_color} ${fg[red]}CMD${reset_color}]" \
    "[${fg[green]}--without-tmux${reset_color}]\n" \
    "where:\n" \
    "\t${fg[red]}TITLE${reset_color}: ${fg[yellow]}the terminal " \
      "title and tmux session name${reset_color}" \
      "(default: ${fg[yellow]}${_default_title}${reset_color})\n" \
    "\t${fg[red]}CMD${reset_color}: " \
      "${fg[yellow]}the command to be executed${reset_color}" \
      "(default: ${fg[yellow]}no command execution${reset_color})\n"
}

# }}}

# {{{ Parse options.

zparseopts -A _opts -title: -cmd: -help -without-tmux

if [[ $? -ne 0 ]]; then
  usage
  exit -1
fi

_with_title=$([ -z "${(k)_opts[--title]}" ] && echo 0 || echo 1)
_title=${(v)_opts[--title]}

_with_cmd=$([ -z "${(k)_opts[--cmd]}" ] && echo 0 || echo 1)
_cmd=${(v)_opts[--cmd]}

_with_help=$([ -z "${(k)_opts[--help]}" ] && echo 0 || echo 1)

_with_tmux=$([ -z "${(k)_opts[--without-tmux]}" ] && echo 1 || echo 0)

# }}}


if [[ ${_with_help} -ne 0 ]]; then # {{{ Show help.
  usage
  exit 0
  # }}}
else # {{{ Entry point.
  if [[ ${_with_title} -eq 0 ]]; then
    _title=${_default_title}
  fi

  if [[ ${_with_cmd} -eq 0 ]];then
    if [[ ${_with_tmux} -eq 0 ]]; then
      TMUX="" ${_urxvt_cmd} -title "${_title}" -e zsh -i
    else
      TMUX="" ${_urxvt_cmd} -title "${_title}" -e zsh -i -c \
        "tmux new-session -s ${(qq)_title}"
    fi
  else
    if [[ ${_with_tmux} -eq 0 ]]; then
      TMUX="" ${_urxvt_cmd} -title "${_title}" -e zsh -i -c "${_cmd}"
    else
      TMUX="" ${_urxvt_cmd} -title "${_title}" -e zsh -i -c \
        "tmux new-session -s ${(qq)_title} ${(qq)_cmd}"
    fi
  fi
fi # }}}


# vim: set filetype=zsh:
