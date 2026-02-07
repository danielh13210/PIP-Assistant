#!/bin/bash

pip3 list --format --outdated json 2>/dev/null | jq -cMr '[.[].name]'
