#!/bin/bash

pip3 list --format json --outdated 2>/dev/null | jq -cMr '[.[].name]'
