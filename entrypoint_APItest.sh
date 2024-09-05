#!/bin/bash

set -e
set -x

function error_handler() {
  echo 'Task failed'
  exit 1
}

trap error_handler ERR

cd /tmp || exit

readonly DATE=$(date +%Y%m%d%H%M%s)
readonly INPUT_FILE_PATH="input-${DATE}"

mkdir "$INPUT_FILE_PATH"

# PUT_BODY=$(printf '{"type":"start"}')
curl -X GET -v "https://ehpks1a2oe.execute-api.ap-northeast-1.amazonaws.com/pointcloud/tasks/6cb338018b75847f" -H 'Content-Type: application/json'