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

# 1. PUT [started_at = xxxxx]
PUT_BODY=$(printf '{"type":"start"}')
PUT_RESPONSE=$(curl -X PUT -v "$POINT_CLOUD_API_URL"/tasks/"$TASK_ID" -H 'Content-Type: application/json' \
-d "$PUT_BODY")

# 2. Download pointcloud data from download_url specified in the POST API Call
curl -o ./"$INPUT_FILE_PATH"/"$FILE_NAME" "$DOWNLOAD_URL"
cd "$INPUT_FILE_PATH" || exit

# 3. Execute Data processing (CloudCompare in this case)
eval timeout 5m CloudCompare -SILENT -O "$FILE_NAME" "$CC_OPTION"

# !!NOTE: If both Input & Output PointCloud data are both .txt, 
# OUTPUT_FILE_NAME will only be Input.txt --> data processed, but the returned one is the original Input.txt
for x in *.{las,csv,e57,xyz}
do
  if [ -f "$x" ]; then
    OUTPUT_FILE_NAME=$x
  fi
done

# 4. OBTAIN Upload url ("PUT_URL") for PointCloud to be uploaded in Step 3
UPLOAD_BODY=$(printf '{"name":"%s"}' "$TASK_ID"/"$OUTPUT_FILE_NAME")
UPLOAD_RESPONSE=$(curl -X POST -v "$IMAGE_UPLOAD_API_URL" -H 'Content-Type: application/json' \
-d "$UPLOAD_BODY")
echo "UPLOAD_RESPONSE: $UPLOAD_RESPONSE"
PUT_URL=$(echo "$UPLOAD_RESPONSE" | jq -r .signedUrl)

# 5. UPLOAD processed PointCloud data to presigned_s3_url obtained previously
PUT_RESPONSE=$(curl -X PUT --upload-file /tmp/"$INPUT_FILE_PATH"/"$OUTPUT_FILE_NAME" "$PUT_URL")
PUT_STATUS=$(echo "$PUT_RESPONSE" | tail -n 1)

# 6. SEND download_url: "https://async-api-for-pointcloud.s3.ap-northeast-1.amazonaws.com/" + requestJson.path to Dynamodb Table
# PUT [finished_at = xxxxx]
FINISH_BODY=$(printf '{"type":"finish","path":"%s"}' "$TASK_ID"/"$OUTPUT_FILE_NAME")
FINISH_RESPONSE=$(curl -X PUT -v "$POINT_CLOUD_API_URL"/tasks/"$TASK_ID" -H 'Content-Type: application/json' \
-d "$FINISH_BODY")%