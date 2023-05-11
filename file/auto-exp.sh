#!/bin/bash
today=$(date +%Y-%m-%d)

for file in /etc/v2ray/config/*.json; do
  echo "Users with exp equal to $today in $file:"
  grep -Eo '"utag": "[^"]+"|"exp": "'"$today"'"' "$file" \
    | grep -B1 "exp\": \"$today\"" \
    | grep -Eo '"utag": "[^"]+"' \
    | cut -d\" -f4 \
    | while read username; do
        echo "Deleting user $username"
        sed -i "/\"utag\": \"$username\"/,/{/d" "$file"
      done
done