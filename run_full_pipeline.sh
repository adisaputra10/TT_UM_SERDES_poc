#!/bin/bash
set -e

# Configuration
DOCKER_IMAGE="goldenways/design-chip:v1.1"
WORKSPACE_DIR="/workspace"
GDS_IMAGES_DIR="${WORKSPACE_DIR}/gds_images"

# OSS Configuration (from environment variables)
# Set these before running:
#   export OSS_ACCESS_KEY_ID="your_key"
#   export OSS_ACCESS_KEY_SECRET="your_secret"
#   export OSS_BUCKET="devops-lab"
#   export OSS_REGION="oss-ap-southeast-5.aliyuncs.com"

if [ -z "${OSS_ACCESS_KEY_ID}" ] || [ -z "${OSS_ACCESS_KEY_SECRET}" ]; then
    echo "Error: OSS credentials not set!"
    echo "Please set environment variables:"
    echo "  export OSS_ACCESS_KEY_ID=..."
    echo "  export OSS_ACCESS_KEY_SECRET=..."
    echo "  export OSS_BUCKET=devops-lab"
    echo "  export OSS_REGION=oss-ap-southeast-5.aliyuncs.com"
    exit 1
fi

OSS_BUCKET="${OSS_BUCKET:-devops-lab}"
OSS_REGION="${OSS_REGION:-oss-ap-southeast-5.aliyuncs.com}"
OSS_ENDPOINT="https://${OSS_REGION}"

# Design info
DESIGN_NAME="tt_um_serdes"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OSS_PREFIX="gds/${DESIGN_NAME}/${TIMESTAMP}"

echo "========================================="
echo "Chip Design Pipeline"
echo "========================================="
echo "Docker Image: ${DOCKER_IMAGE}"
echo "Design: ${DESIGN_NAME}"
echo "Timestamp: ${TIMESTAMP}"
echo "OSS Bucket: ${OSS_BUCKET}"
echo "OSS Prefix: ${OSS_PREFIX}"
echo "========================================="

# Step 1: Pull Docker image from Docker Hub
echo ""
echo "[STEP 1] Pulling Docker image from Docker Hub..."
docker pull ${DOCKER_IMAGE}
echo "✓ Docker image pulled successfully"

# Step 2: Run harden flow
echo ""
echo "[STEP 2] Running harden flow..."
docker run --rm \
    -v ${WORKSPACE_DIR}:${WORKSPACE_DIR} \
    -w ${WORKSPACE_DIR} \
    ${DOCKER_IMAGE} \
    bash run_harden_openlane1.sh

echo "✓ Harden flow completed"

# Step 3: Check GDS files
echo ""
echo "[STEP 3] Checking GDS files..."
GDS_DIR="${WORKSPACE_DIR}/TT_UM_SERDES_poc/runs/harden/results/signoff"
GDS_FILES=$(ls -1 ${GDS_DIR}/*.gds 2>/dev/null | wc -l)

if [ ${GDS_FILES} -eq 0 ]; then
    echo "✗ Error: No GDS files found!"
    exit 1
fi

echo "Found ${GDS_FILES} GDS file(s):"
ls -lh ${GDS_DIR}/*.gds
echo "✓ GDS files generated successfully"

# Step 4: Convert GDS to images
echo ""
echo "[STEP 4] Converting GDS to images..."
docker run --rm \
    -v ${WORKSPACE_DIR}:${WORKSPACE_DIR} \
    -w ${WORKSPACE_DIR} \
    ${DOCKER_IMAGE} \
    python3 gds_to_image.py \
    TT_UM_SERDES_poc/runs/harden/results/signoff/tt_um_serdes.klayout.gds \
    ./gds_images

echo "✓ GDS images generated successfully"

# Step 5: Upload to Alibaba Cloud OSS
echo ""
echo "[STEP 5] Uploading to Alibaba Cloud OSS..."

# Install ossutil if not exists
if ! command -v ossutil &> /dev/null; then
    echo "Installing ossutil..."
    curl -o ossutil64 https://gosspublic.alicdn.com/ossutil/1.7.18/ossutil-v1.7.18-linux-amd64/ossutil64
    chmod 755 ossutil64
    sudo mv ossutil64 /usr/local/bin/ossutil
fi

# Configure ossutil
echo "Configuring ossutil..."
ossutil config \
    -e ${OSS_ENDPOINT} \
    -i ${OSS_ACCESS_KEY_ID} \
    -k ${OSS_ACCESS_KEY_SECRET}

# Upload GDS files
echo "Uploading GDS files..."
for gds_file in ${GDS_DIR}/*.gds; do
    filename=$(basename ${gds_file})
    echo "  Uploading: ${filename}"
    ossutil cp ${gds_file} oss://${OSS_BUCKET}/${OSS_PREFIX}/gds/${filename}
done

# Upload images
echo "Uploading GDS images..."
for img_file in ${GDS_IMAGES_DIR}/*.png; do
    filename=$(basename ${img_file})
    echo "  Uploading: ${filename}"
    ossutil cp ${img_file} oss://${OSS_BUCKET}/${OSS_PREFIX}/images/${filename}
done

# Upload summary
echo "Uploading summary..."
if [ -f ${GDS_IMAGES_DIR}/summary.txt ]; then
    ossutil cp ${GDS_IMAGES_DIR}/summary.txt oss://${OSS_BUCKET}/${OSS_PREFIX}/summary.txt
fi

echo "✓ Upload completed successfully"

# Step 6: Generate public URLs
echo ""
echo "[STEP 6] Generating public URLs..."
echo ""
echo "========================================="
echo "UPLOAD SUMMARY"
echo "========================================="
echo "OSS Bucket: ${OSS_BUCKET}"
echo "OSS Prefix: ${OSS_PREFIX}"
echo ""
echo "GDS Files:"
for gds_file in ${GDS_DIR}/*.gds; do
    filename=$(basename ${gds_file})
    url="${OSS_ENDPOINT}/${OSS_BUCKET}/${OSS_PREFIX}/gds/${filename}"
    echo "  - ${filename}"
    echo "    ${url}"
done
echo ""
echo "Images:"
for img_file in ${GDS_IMAGES_DIR}/*.png; do
    filename=$(basename ${img_file})
    url="${OSS_ENDPOINT}/${OSS_BUCKET}/${OSS_PREFIX}/images/${filename}"
    echo "  - ${filename}"
    echo "    ${url}"
done
echo ""
echo "Summary:"
echo "  - summary.txt"
echo "    ${OSS_ENDPOINT}/${OSS_BUCKET}/${OSS_PREFIX}/summary.txt"
echo "========================================="
echo ""
echo "✓ Pipeline completed successfully!"
echo "All files uploaded to OSS and accessible via public URLs"
