#!/bin/zsh

# Create useful gitignore files
# Usage: gi [param]
# param is a comma separated list of ignore profiles.
# If param is ommited choose interactively.

function __fzf_gitignore() {
  curl -L -s https://www.gitignore.io/api/"$@"
}

if  [ "$#" -eq 0 ]; then
  IFS+=","
  for item in $(__fzf_gitignore list); do
    echo $item
  done | fzf --multi --ansi | paste -s -d "," - |
  { read result && __fzf_gitignore "$result"; }
else
  __fzf_gitignore "$@"
fi
