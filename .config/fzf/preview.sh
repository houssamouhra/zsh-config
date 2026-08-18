#!/usr/bin/env bash

if [ -d "$1" ]; then
	eza --tree --level=3 --color=always "$1" | head -200
else
	if file --mime-type "$1" | grep -q binary; then
		echo "Binary file"
	else
		bat --color=always --line-range :500 "$1"
	fi
fi
