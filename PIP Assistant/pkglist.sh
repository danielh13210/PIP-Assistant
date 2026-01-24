#!/bin/bash

pip3 list --format json 2>/dev/null | jq -cMr '[.[].name]'
