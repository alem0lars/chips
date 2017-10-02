#!/bin/zsh


exec optirun /usr/bin/chromium --disable-gpu-sandbox "$@"
