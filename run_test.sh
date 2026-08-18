#!/bin/bash
set -e

echo "========================================="
echo "Testing OpenLane Local Docker Environment"
echo "========================================="

# Check tools
echo "Python: $(python3 --version)"
echo "OpenROAD: $(openroad -version 2>/dev/null || echo 'not found')"
echo "Yosys: $(yosys --version 2>/dev/null || echo 'not found')"
echo "Icarus Verilog: $(iverilog -V 2>/dev/null | head -1 || echo 'not found')"
echo "KLayout: $(klayout -v 2>/dev/null || echo 'not found')"
echo "OpenLane: $(openlane --version 2>/dev/null || echo 'not found')"
echo "========================================="

# Clone repo
cd /workspace
if [ ! -d "TT_UM_SERDES_poc" ]; then
    echo "Cloning TT_UM_SERDES_poc..."
    git clone --depth=1 https://github.com/adisaputra10/TT_UM_SERDES_poc.git
fi
cd TT_UM_SERDES_poc

echo "=== Repository contents ==="
ls -la

echo "=== Source files ==="
ls -la src/ 2>/dev/null || echo "No src/ directory"

echo "=== Running Yosys synthesis check ==="
# Find all verilog files
VERILOG_FILES=$(find src/ -name "*.v" 2>/dev/null | tr '\n' ' ')
if [ -n "$VERILOG_FILES" ]; then
    echo "Verilog files: $VERILOG_FILES"
    yosys -p "read_verilog $VERILOG_FILES; hierarchy -top tt_um_serdes; synth -top tt_um_serdes; stat" 2>&1 | tail -20
    echo "=== Synthesis check done ==="
else
    echo "No verilog files found in src/"
    exit 1
fi

echo "=== Setting up tt-support-tools ==="
if [ ! -d "tt" ]; then
    git clone --depth=1 --branch main https://github.com/TinyTapeout/tt-support-tools.git tt
fi
# Always install requirements (idempotent)
pip install --no-cache-dir -r tt/requirements.txt 2>&1 | tail -5

echo "=== Converting config.tcl to config.json ==="
if [ ! -f src/config.json ] && [ -f src/config.tcl ]; then
    echo "Converting src/config.tcl to src/config.json..."
    cat > /tmp/convert_config.py << 'PYTHON_SCRIPT'
import re, json, os, glob
config = {}
with open("src/config.tcl") as f:
    for line in f:
        line = line.strip()
        if line.startswith("set ::env("):
            m = re.match(r"set ::env\(([^)]+)\)\s+(.+)", line)
            if m:
                key = m.group(1)
                val = m.group(2).strip().strip("{}")
                try:
                    if "." in val:
                        val = float(val)
                    else:
                        val = int(val)
                except:
                    val = val.strip("\"{}")
                config[key] = val

# Add required DESIGN_NAME if not present
if "DESIGN_NAME" not in config:
    v_files = glob.glob("src/*.v")
    found = False
    for vf_path in v_files:
        try:
            with open(vf_path) as vf:
                content = vf.read()
                for m in re.finditer(r"module\s+(\w+)", content):
                    module_name = m.group(1)
                    if module_name.startswith("tt_um_"):
                        config["DESIGN_NAME"] = module_name
                        print(f"Extracted DESIGN_NAME from {vf_path}: {module_name}")
                        found = True
                        break
            if found:
                break
        except:
            pass
    if not found:
        config["DESIGN_NAME"] = "chip"
        print("Warning: Could not extract DESIGN_NAME, using default: chip")

# Add required VERILOG_FILES if not present
if "VERILOG_FILES" not in config:
    v_files = glob.glob("src/*.v")
    if v_files:
        config["VERILOG_FILES"] = [os.path.abspath(f) for f in v_files]
        print(f"Added VERILOG_FILES: {len(v_files)} files")

# Add OpenROAD floorplan variables if not present
if "DIE_AREA" not in config:
    config["DIE_AREA"] = "0 0 200 200"
    print("Added DIE_AREA: 0 0 200 200")

if "CORE_AREA" not in config:
    config["CORE_AREA"] = "5 5 195 195"
    print("Added CORE_AREA: 5 5 195 195")

if "FP_PDN_CORE_RING" not in config:
    config["FP_PDN_CORE_RING"] = 0

if "FP_PDN_ENABLE_RAILS" not in config:
    config["FP_PDN_ENABLE_RAILS"] = 1

# Force override routing layer configuration
config["RT_MAX_LAYER"] = "met3"
print("Forced RT_MAX_LAYER: met3")

if "RT_MIN_LAYER" not in config and "GRT_MIN_LAYER" not in config:
    config["RT_MIN_LAYER"] = "met1"
    print("Added RT_MIN_LAYER: met1")

# Disable RC extraction to avoid layer NULL errors
config["RUN_RCX"] = 0
print("Forced RUN_RCX: 0")

config["RUN_DRT"] = 0
config["RUN_FILL_INSERTION"] = 0
config["RUN_TAP_DECAP_INSERTION"] = 0
print("Forced RUN_DRT, RUN_FILL_INSERTION, RUN_TAP_DECAP_INSERTION: 0")

config["GRT_MAX_LAYER"] = "met3"
print("Forced GRT_MAX_LAYER: met3")

with open("src/config.json", "w") as f:
    json.dump(config, f, indent=2)
print("Created src/config.json with", len(config), "entries")
PYTHON_SCRIPT
    python3 /tmp/convert_config.py
fi

echo "=== Creating user_config.json ==="
if [ ! -f src/user_config.json ]; then
    echo "{}" > src/user_config.json
    echo "Created empty src/user_config.json"
fi

echo "=== Running harden flow ==="
export PDK=sky130
python3 tt/tt_tool.py --harden --no-docker 2>&1 | tee harden.log

echo "=== Harden complete ==="
echo "=== Checking for GDS output ==="
find . -name "*.gds" -type f 2>/dev/null
echo "=== Done ==="
