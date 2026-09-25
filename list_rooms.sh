#!/bin/sh
cd /app
for f in test_minimal_world_v2_modified/room/*.c; do
  echo "=== $f ==="
  grep -H 'short' "$f" | head -3
done