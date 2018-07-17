#!/bin/zsh

autoload colors
colors

user="${1}"
machine="${2}"
workdir="${3}"
cmd="${4}"

prompt="$fg_no_bold[red]${user}@${machine}${reset_color}:$fg_no_bold[cyan]${workdir}$reset_color$"

echo "${prompt} $fg_no_bold[green]${cmd}$reset_color"
while read line
do
  echo "$line"
done < /dev/stdin
