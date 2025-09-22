#!/bin/sh
echo -ne '\033c\033]0;voip tutorial\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/voip_tutorial.x86_64" "$@"
