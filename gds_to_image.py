#!/usr/bin/env python3
"""
GDS to Image Converter - Simplified Version
Convert GDS files to various image formats with different visualizations
"""

import pya
import sys
import os

def convert_gds_to_images(gds_path, output_dir):
    """Convert GDS file to multiple image formats"""
    
    print(f"Loading GDS file: {gds_path}")
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Load layout
    layout = pya.Layout()
    layout.read(gds_path)
    
    top_cell = layout.top_cell()
    if not top_cell:
        print("Error: No top cell found in GDS")
        return
    
    print(f"Top cell: {top_cell.name}")
    print(f"Total cells: {len(list(layout.each_cell()))}")
    
    # Get bounding box
    bbox = top_cell.bbox()
    dbu = layout.dbu
    width_um = bbox.width() * dbu
    height_um = bbox.height() * dbu
    
    print(f"Die size: {width_um:.2f} x {height_um:.2f} um")
    print(f"Area: {width_um * height_um:.2f} um^2")
    
    # 1. Generate overview image (full layout)
    print("\n1. Generating overview image...")
    view = pya.LayoutView()
    view.load_layout(gds_path, False)
    view.max_hier()
    view.zoom_fit()
    
    overview_path = os.path.join(output_dir, '01_overview.png')
    view.save_image(overview_path, 4000, 4000)
    print(f"   Saved: {overview_path}")
    
    # 2. Generate high-resolution overview
    print("2. Generating high-resolution overview...")
    hires_path = os.path.join(output_dir, '02_overview_hires.png')
    view.save_image(hires_path, 8000, 8000)
    print(f"   Saved: {hires_path}")
    
    # 3. Generate colored view
    print("3. Generating colored view...")
    colored_view = pya.LayoutView()
    colored_view.load_layout(gds_path, False)
    colored_view.max_hier()
    colored_view.zoom_fit()
    
    colored_path = os.path.join(output_dir, '03_colored_view.png')
    colored_view.save_image(colored_path, 4000, 4000)
    print(f"   Saved: {colored_path}")
    
    # 4. Generate zoomed views (corners and center)
    print("4. Generating zoomed views...")
    
    # Calculate zoom regions
    center_x = (bbox.left + bbox.right) / 2
    center_y = (bbox.bottom + bbox.top) / 2
    zoom_size = min(width_um, height_um) * 0.2  # 20% of smallest dimension
    
    zoom_regions = {
        'center': (center_x, center_y),
        'bottom_left': (bbox.left + zoom_size/2, bbox.bottom + zoom_size/2),
        'bottom_right': (bbox.right - zoom_size/2, bbox.bottom + zoom_size/2),
        'top_left': (bbox.left + zoom_size/2, bbox.top - zoom_size/2),
        'top_right': (bbox.right - zoom_size/2, bbox.top - zoom_size/2),
    }
    
    for region_name, (cx, cy) in zoom_regions.items():
        zoom_view = pya.LayoutView()
        zoom_view.load_layout(gds_path, False)
        zoom_view.max_hier()
        
        # Zoom to region
        zoom_box = pya.DBox(
            cx - zoom_size/2, cy - zoom_size/2,
            cx + zoom_size/2, cy + zoom_size/2
        )
        zoom_view.zoom_box(zoom_box)
        
        zoom_filename = f"04_zoom_{region_name}.png"
        zoom_path = os.path.join(output_dir, zoom_filename)
        zoom_view.save_image(zoom_path, 3000, 3000)
        print(f"   {region_name}: {zoom_filename}")
    
    # 5. Generate summary report
    print("5. Generating summary report...")
    report_path = os.path.join(output_dir, 'summary.txt')
    
    # Count layers
    layer_info_list = []
    for layer_idx in layout.layer_indices():
        linfo = layout.get_info(layer_idx)
        shape_count = 0
        for shape in top_cell.each_shape(layer_idx):
            shape_count += 1
        if shape_count > 0:
            layer_info_list.append((linfo.layer, linfo.datatype, shape_count))
    
    with open(report_path, 'w') as f:
        f.write("=" * 60 + "\n")
        f.write("GDS LAYOUT SUMMARY\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"File: {gds_path}\n")
        f.write(f"Top Cell: {top_cell.name}\n")
        f.write(f"Total Cells: {len(list(layout.each_cell()))}\n")
        f.write(f"Database Unit: {dbu} um\n")
        f.write(f"Die Size: {width_um:.2f} x {height_um:.2f} um\n")
        f.write(f"Area: {width_um * height_um:.2f} um^2\n\n")
        
        f.write("LAYERS:\n")
        f.write("-" * 60 + "\n")
        f.write(f"{'Layer':<10} {'Datatype':<10} {'Shapes':<10}\n")
        f.write("-" * 60 + "\n")
        
        for layer_num, datatype, shape_count in layer_info_list:
            f.write(f"{layer_num:<10} {datatype:<10} {shape_count:<10}\n")
        
        f.write("-" * 60 + "\n")
        f.write(f"Total layers with shapes: {len(layer_info_list)}\n\n")
        
        f.write("GENERATED IMAGES:\n")
        f.write("-" * 60 + "\n")
        for filename in sorted(os.listdir(output_dir)):
            if filename.endswith('.png'):
                filepath = os.path.join(output_dir, filename)
                size_kb = os.path.getsize(filepath) / 1024
                f.write(f"{filename:<40} {size_kb:>8.1f} KB\n")
    
    print(f"   Saved: {report_path}")
    
    print("\n" + "=" * 60)
    print("CONVERSION COMPLETE!")
    print("=" * 60)
    print(f"Output directory: {output_dir}")
    print(f"Total images generated: {len([f for f in os.listdir(output_dir) if f.endswith('.png')])}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python gds_to_image.py <gds_file> [output_dir]")
        print("Example: python gds_to_image.py tt_um_serdes.gds ./gds_images")
        sys.exit(1)
    
    gds_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else './gds_images'
    
    if not os.path.exists(gds_file):
        print(f"Error: GDS file not found: {gds_file}")
        sys.exit(1)
    
    convert_gds_to_images(gds_file, output_dir)
