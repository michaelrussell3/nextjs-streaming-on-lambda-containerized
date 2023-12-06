#!/bin/bash
# Execute server.js, which is output using "next build"
mkdir -p /tmp/nextjs-cache
exec node server.js