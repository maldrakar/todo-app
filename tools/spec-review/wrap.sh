#!/bin/sh
# Wraps the artifact body in the publish skeleton for a local look.
printf '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;box-sizing:border-box}body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}img{max-width:100%%}</style></head><body>' > "$2"
cat "$1" >> "$2"
printf '</body></html>' >> "$2"
