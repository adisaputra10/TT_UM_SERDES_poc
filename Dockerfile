# Multi-stage build: copy OpenROAD from efabless/openlane, install librelane in Python
FROM efabless/openlane:latest AS openlane_base

FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    build-essential \
    tcl \
    tclsh \
    tk \
    tk-dev \
    swig \
    cmake \
    libffi-dev \
    libssl-dev \
    libreadline-dev \
    libbz2-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libboost-all-dev \
    libfmt-dev \
    libspdlog-dev \
    libcairo2-dev \
    libpango1.0-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Nix store from efabless/openlane image (contains all EDA tools)
COPY --from=openlane_base /nix/ /nix/

# Create symlinks for all EDA tools from Nix store
RUN ln -sf /nix/store/7g30wn9qnkcvnkk5h9q1cqk0yl86qxil-openroad/bin/openroad /usr/local/bin/openroad && \
    ln -sf /nix/store/sx2v0i73mn1ih2z1nk61pm9n5gjgpidy-yosys/bin/yosys /usr/local/bin/yosys && \
    ln -sf /nix/store/vh3lcg8gq2c3pxbqkqmrk3fmf3papk52-iverilog-12.0/bin/iverilog /usr/local/bin/iverilog && \
    ln -sf /nix/store/zdin7gzr638czb3isvn7hf2vrnm3k289-klayout/bin/klayout /usr/local/bin/klayout && \
    ln -sf /nix/store/vqkxcjih78792qy07hw88gg0v3svr95a-magic-vlsi/bin/magic /usr/local/bin/magic && \
    ln -sf /nix/store/b9kirpfkif1852bcy64f96np93xjalsi-netgen/bin/netgen /usr/local/bin/netgen && \
    ln -sf /nix/store/mky7gdsf8m3da333lxz2mjf2n3n1v1xy-verilator/bin/verilator /usr/local/bin/verilator

# Install volare and dependencies
RUN pip install --no-cache-dir volare pyyaml click rich chevron

# Install librelane 2.4.13 (compatible with yosys 0.38)
RUN pip install --no-cache-dir librelane==2.4.13

# Install volare and download sky130 PDK using tool_metadata.yml from OpenLane
RUN volare enable --pdk sky130 --metadata-file /nix/store/n80jab4y02mx8pq7lxpr527x3cdai5a9-dependencies/tool_metadata.yml

# Create symlink so OpenLane 1.1.1 can find the PDK
RUN ln -sf /root/.volare/sky130A /root/.volare/sky130

# Create SPEF extractor symlinks for OpenLane 1.1.1 compatibility
# OpenLane 1.1.1 looks for rules.openrcx.sky130.* but PDK has rules.openrcx.sky130A.*
RUN cd /root/.volare/sky130/libs.tech/openlane && \
    ln -sf rules.openrcx.sky130A.min.spef_extractor rules.openrcx.sky130.min.spef_extractor && \
    ln -sf rules.openrcx.sky130A.nom.spef_extractor rules.openrcx.sky130.nom.spef_extractor && \
    ln -sf rules.openrcx.sky130A.max.spef_extractor rules.openrcx.sky130.max.spef_extractor

# Create KLayout tech file symlinks for OpenLane 1.1.1 compatibility
# OpenLane 1.1.1 looks for sky130.* but PDK has sky130A.*
RUN cd /root/.volare/sky130/libs.tech/klayout/tech && \
    ln -sf sky130A.lyt sky130.lyt && \
    ln -sf sky130A.map sky130.map && \
    ln -sf sky130A.lyp sky130.lyp

# Set environment variables
ENV PDK_ROOT=/root/.volare
ENV PDK=sky130
ENV STD_CELL_LIBRARY=sky130_fd_sc_hd

# Create working directory
WORKDIR /workspace

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
