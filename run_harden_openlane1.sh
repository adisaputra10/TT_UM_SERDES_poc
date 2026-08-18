#!/bin/bash
set -e

echo "========================================="
echo "Harden Flow using OpenLane 1.1.1 (TCL)"
echo "========================================="

cd /workspace

# Clone repo if not exists
if [ ! -d "TT_UM_SERDES_poc" ]; then
    echo "Cloning TT_UM_SERDES_poc..."
    git clone --depth=1 https://github.com/adisaputra10/TT_UM_SERDES_poc.git
fi
cd TT_UM_SERDES_poc

echo "=== Source files ==="
ls -la src/

# Find the OpenLane 1.1.1 flow.tcl
OPENLANE_DIR=$(find /nix/store -maxdepth 1 -name "*openlane1*" -type d 2>/dev/null | head -1)
if [ -z "$OPENLANE_DIR" ]; then
    echo "ERROR: OpenLane 1.1.1 not found in /nix/store"
    exit 1
fi
echo "=== OpenLane 1.1.1 directory: $OPENLANE_DIR ==="

FLOW_TCL=$(find "$OPENLANE_DIR" -name "flow.tcl" 2>/dev/null | head -1)
if [ -z "$FLOW_TCL" ] || [ ! -f "$FLOW_TCL" ]; then
    echo "ERROR: flow.tcl not found in $OPENLANE_DIR"
    exit 1
fi
echo "=== Using flow.tcl: $FLOW_TCL ==="

# Create a run directory
mkdir -p runs/harden

# Prepare design config
DESIGN_NAME="tt_um_serdes"
VERILOG_FILES=$(find src/ -name "*.v" | sort | tr '\n' ' ')
echo "=== Design: $DESIGN_NAME ==="
echo "=== Verilog files: $VERILOG_FILES ==="

# Create user_config.tcl with required variables (OpenLane 1.1.1 requires it)
rm -f user_config.tcl
if [ ! -f user_config.tcl ]; then
    echo "Creating user_config.tcl with design variables"
    # Get absolute paths for verilog files in TCL list format
    VERILOG_LIST=$(find $(pwd)/src/ -name "*.v" | sort | tr '\n' ' ')
    cat > user_config.tcl << EOF
set ::env(DESIGN_NAME) "tt_um_serdes"
set ::env(VERILOG_FILES) {$VERILOG_LIST}
set ::env(VERILOG_FILES_BLACKBOX) {}

# Die and core area (in microns)
# For a small design like SERDES (~253 cells), use 200x200 um die
set ::env(DIE_AREA) "0 0 200 200"
set ::env(CORE_AREA) "5 5 195 195"
EOF
    echo "user_config.tcl contents:"
    cat user_config.tcl
fi

# PDK setup
export PDK_ROOT=/root/.volare
export DESIGN_DIR=$(pwd)

# Run OpenLane 1.1.1 flow
echo "=== Running OpenLane 1.1.1 harden flow ==="
"$FLOW_TCL" \
    -design_dir $(pwd) \
    -design_name "$DESIGN_NAME" \
    -config_file src/config.tcl \
    -tag harden \
    -overwrite 2>&1 | tee openlane_harden.log || true

echo "=== Harden flow complete ==="

# Check for GDS output
echo "=== Checking for GDS output ==="
find runs/ -name "*.gds" 2>/dev/null || echo "No GDS files found"

echo "=== Done ==="
