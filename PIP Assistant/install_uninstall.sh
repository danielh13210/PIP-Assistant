#!/bin/sh

#this file is a template, the directives will be replaced by the app
if [ "{{CMD}}" == "upgrade" ]; then
  CMD="install --upgrade"
else
  CMD="{{CMD}}"
fi
pip3 $CMD "{{PACKAGE_NAME}}"
open pipassistant://busy_complete
echo "The operation has completed. You may now close this window."
