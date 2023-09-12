#!/bin/sh
echo -ne '\033c\033]0;Lander\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Lander.x86_64" "$@"
