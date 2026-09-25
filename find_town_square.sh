#!/bin/sh
cd /app
for f in test_minimal_world_v2_modified/room/*.c; do
  if grep -q 'town_square' "$f" 2>/dev/null; then
    echo "=== $f ==="
    cat "$f"
  fi
done