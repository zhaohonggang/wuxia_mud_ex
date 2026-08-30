#!/bin/bash
sed -i 's|%__MODULE_\$\{\}|%__MODULE__{}|g' /app/lib/kantele/character/vitals.ex
head -80 /app/lib/kantele/character/vitals.ex
