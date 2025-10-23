#!/bin/bash

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# check if bucket name is provided
if [ -z "$1" ]; then
    echo -e "${RED}error: bucket name required${NC}"
    echo "usage: $0 <bucket-name>"
    exit 1
fi

BUCKET_NAME="$1"
RUN_ID=$(date +%s)-$$
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_IMAGE="$SCRIPT_DIR/test-image.jpg"

# check if test image exists
if [ ! -f "$TEST_IMAGE" ]; then
    echo -e "${RED}error: test image not found: $TEST_IMAGE${NC}"
    exit 1
fi

echo "===+++++++++++++++++++++++++++++++++++==="
echo "image processing pipeline test"
echo "===+++++++++++++++++++++++++++++++++++==="
echo "bucket: $BUCKET_NAME"
echo "run id: $RUN_ID"
echo "test image: $TEST_IMAGE"
echo "===+++++++++++++++++++++++++++++++++++==="

# define upload targets
PREFIXES=("resize" "greyscale" "exif")

# upload images to each prefix
echo ""
echo "uploading test images..."
for prefix in "${PREFIXES[@]}"; do
    S3_KEY="${prefix}/test-${RUN_ID}.jpg"
    echo -n "  uploading to s3://${BUCKET_NAME}/${S3_KEY}... "

    if aws s3 cp "$TEST_IMAGE" "s3://${BUCKET_NAME}/${S3_KEY}" --quiet; then
        echo -e "${GREEN}pass${NC}"
    else
        echo -e "${RED}fail${NC}"
        exit 1
    fi
done

# wait for processing
WAIT_TIME=20
echo ""
echo -e "${YELLOW}waiting ${WAIT_TIME} seconds for lambda processing...${NC}"
sleep $WAIT_TIME

# download processed images
echo ""
echo "downloading processed images..."

SUCCESS_COUNT=0
FAIL_COUNT=0

# check resize
echo -n "  checking processed/resize/test-${RUN_ID}.jpg... "
if aws s3 cp "s3://${BUCKET_NAME}/processed/resize/test-${RUN_ID}.jpg" "$SCRIPT_DIR/output-resize-${RUN_ID}.jpg" --quiet 2>/dev/null; then
    echo -e "${GREEN}pass${NC}"
    ((SUCCESS_COUNT++))
else
    echo -e "${RED}fail${NC}"
    ((FAIL_COUNT++))
fi

# check greyscale
echo -n "  checking processed/greyscale/test-${RUN_ID}.jpg... "
if aws s3 cp "s3://${BUCKET_NAME}/processed/greyscale/test-${RUN_ID}.jpg" "$SCRIPT_DIR/output-greyscale-${RUN_ID}.jpg" --quiet 2>/dev/null; then
    echo -e "${GREEN}pass${NC}"
    ((SUCCESS_COUNT++))
else
    echo -e "${RED}fail${NC}"
    ((FAIL_COUNT++))
fi

# check exif (json file)
echo -n "  checking processed/exif/test-${RUN_ID}.json... "
if aws s3 cp "s3://${BUCKET_NAME}/processed/exif/test-${RUN_ID}.json" "$SCRIPT_DIR/output-exif-${RUN_ID}.json" --quiet 2>/dev/null; then
    echo -e "${GREEN}pass${NC}"
    echo "    exif data preview:"
    head -5 "$SCRIPT_DIR/output-exif-${RUN_ID}.json" | sed 's/^/    /'
    ((SUCCESS_COUNT++))
else
    echo -e "${RED}fail${NC}"
    ((FAIL_COUNT++))
fi

# summary
echo ""
echo "===+++++++++++++++++++++++++++++++++++==="
echo "test summary"
echo "===+++++++++++++++++++++++++++++++++++==="
echo "successful: ${SUCCESS_COUNT}/3"
echo "failed: ${FAIL_COUNT}/3"
echo "===+++++++++++++++++++++++++++++++++++==="

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}all tests passed${NC}"
    echo ""
    echo "downloaded files:"
    ls -lh "$SCRIPT_DIR"/output-*-${RUN_ID}.* 2>/dev/null || true
    exit 0
else
    echo -e "${RED}some tests failed${NC}"
    exit 1
fi
