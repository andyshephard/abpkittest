#!/bin/sh

# Update bundled block lists in ABPKit.
#
# Run from the project root with:
#
# $ Scripts/update-bundled-blocklists.sh

OUTPUT_PATH="ABPKit/Common/Resources/"
source "Scripts/blocklists-default.txt"

curl -o $OUTPUT_PATH/easylist_content_blocker.json $EASYLIST
curl -o $OUTPUT_PATH/easylist+exceptionrules_content_blocker.json $EASYLIST_PLUS_EXCEPTIONS
