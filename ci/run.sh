#!/bin/bash
# Execute server.js, which is output using "next build"
mkdir -p /tmp/next-cache && ln -s /tmp/next-cache /var/task/.next/cache
exec node server.js