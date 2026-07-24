#!/usr/bin/env bash
# Delete resource group for an environment (wrapper for remove.sh).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/remove.sh" remove "$@"
