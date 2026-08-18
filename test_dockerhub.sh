#!/bin/bash
set -e

# Simple test script - Pull from Docker Hub and run
DOCKER_IMAGE="goldenways/design-chip:v1.1"

echo "Pulling image from Docker Hub..."
docker pull ${DOCKER_IMAGE}

echo ""
echo "Running harden flow..."
docker run --rm \
    -v $(pwd):/workspace \
    -w /workspace \
    ${DOCKER_IMAGE} \
    bash run_harden_openlane1.sh

echo ""
echo "Converting GDS to images..."
docker run --rm \
    -v $(pwd):/workspace \
    -w /workspace \
    ${DOCKER_IMAGE} \
    python3 gds_to_image.py \
    TT_UM_SERDES_poc/runs/harden/results/signoff/tt_um_serdes.klayout.gds \
    ./gds_images

echo ""
echo "✓ Done! Check gds_images/ folder for results"
ls -lh gds_images/
