#!/bin/sh
cd /app
for f in test_minimal_world_v2_modified/room/*.c; do
  if grep -q 'set.*objects' "$f" 2>/dev/null; then
    echo "=== $f ==="
    grep -A20 'set.*objects' "$f"
  fi
done