#!/bin/bash

# LiveEventOps - Image Conversion Script
# Converts all demo images/screenshots in the media folder to PNG format for documentation

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="$PROJECT_ROOT/media"
BACKUP_DIR="$MEDIA_DIR/originals"
CONVERTED_DIR="$MEDIA_DIR/png"
LOG_FILE="$MEDIA_DIR/conversion.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

warning() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}${message}${NC}" >&2
    echo "$message" >> "$LOG_FILE"
}

# Function to check required dependencies
check_dependencies() {
    log "Checking required dependencies..."
    
    local missing_deps=()
    
    # Check for ImageMagick (convert command)
    if ! command -v convert &> /dev/null; then
        missing_deps+=("imagemagick")
    fi
    
    # Check for sips (macOS built-in image converter)
    if [[ "$OSTYPE" == "darwin"* ]] && ! command -v sips &> /dev/null; then
        warning "sips not found (unusual for macOS)"
    fi
    
    # Check for ffmpeg (for video thumbnails if needed)
    if ! command -v ffmpeg &> /dev/null; then
        warning "ffmpeg not found - video thumbnail extraction will be skipped"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "To install missing dependencies:"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install imagemagick"
            echo "  brew install ffmpeg  # optional, for video thumbnails"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "  sudo apt-get install imagemagick"
            echo "  sudo apt-get install ffmpeg  # optional, for video thumbnails"
        else
            echo "  Please install ImageMagick for your operating system"
        fi
        
        exit 1
    fi
    
    success "All required dependencies are available"
}

# Function to create necessary directories
setup_directories() {
    log "Setting up directories..."
    
    # Create media directory if it doesn't exist
    if [ ! -d "$MEDIA_DIR" ]; then
        mkdir -p "$MEDIA_DIR"
        log "Created media directory: $MEDIA_DIR"
    fi
    
    # Create backup directory for original images
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "Created backup directory: $BACKUP_DIR"
    fi
    
    # Create converted directory for PNG outputs
    if [ ! -d "$CONVERTED_DIR" ]; then
        mkdir -p "$CONVERTED_DIR"
        log "Created converted directory: $CONVERTED_DIR"
    fi
    
    # Create subdirectories for organized storage
    local subdirs=("screenshots" "diagrams" "demos" "ui" "architecture" "monitoring")
    for subdir in "${subdirs[@]}"; do
        if [ ! -d "$CONVERTED_DIR/$subdir" ]; then
            mkdir -p "$CONVERTED_DIR/$subdir"
            log "Created subdirectory: $CONVERTED_DIR/$subdir"
        fi
    done
    
    success "Directory structure ready"
}

# Function to find all image files in media directory
find_image_files() {
    log "Scanning for image files in $MEDIA_DIR..."
    
    # Define supported image formats
    local image_extensions=("jpg" "jpeg" "bmp" "gif" "tiff" "tif" "webp" "svg" "ico")
    local find_args=()
    
    # Build find command arguments for all image extensions
    for ext in "${image_extensions[@]}"; do
        find_args+=("-name" "*.${ext}" "-o" "-name" "*.${ext^^}")
    done
    
    # Remove the last "-o" from the arguments
    unset find_args[-1]
    
    # Find all image files (exclude PNG files and directories we created)
    local image_files=()
    while IFS= read -r -d '' file; do
        # Skip files in backup and converted directories
        if [[ "$file" != *"/originals/"* ]] && [[ "$file" != *"/png/"* ]]; then
            image_files+=("$file")
        fi
    done < <(find "$MEDIA_DIR" -type f \( "${find_args[@]}" \) -print0 2>/dev/null)
    
    echo "${image_files[@]}"
}

# Function to categorize image by filename/path
categorize_image() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local dirname=$(basename "$(dirname "$filepath")")
    
    # Categorization logic based on filename patterns
    if [[ "$filename" =~ (screenshot|capture|screen) ]] || [[ "$dirname" =~ (screenshot|capture|screen) ]]; then
        echo "screenshots"
    elif [[ "$filename" =~ (diagram|architecture|flow|chart) ]] || [[ "$dirname" =~ (diagram|architecture|flow|chart) ]]; then
        echo "diagrams"
    elif [[ "$filename" =~ (demo|example|sample) ]] || [[ "$dirname" =~ (demo|example|sample) ]]; then
        echo "demos"
    elif [[ "$filename" =~ (ui|interface|dashboard|form) ]] || [[ "$dirname" =~ (ui|interface|dashboard|form) ]]; then
        echo "ui"
    elif [[ "$filename" =~ (monitor|metric|alert|graph) ]] || [[ "$dirname" =~ (monitor|metric|alert|graph) ]]; then
        echo "monitoring"
    else
        echo "general"
    fi
}

# Function to generate descriptive filename
generate_png_filename() {
    local original_file="$1"
    local category="$2"
    
    local basename=$(basename "$original_file")
    local name_without_ext="${basename%.*}"
    
    # Clean up filename for better readability
    local clean_name=$(echo "$name_without_ext" | \
        sed 's/[^a-zA-Z0-9_-]/_/g' | \
        sed 's/__*/_/g' | \
        sed 's/^_*//; s/_*$//')
    
    # Add category prefix if not already present
    if [[ ! "$clean_name" =~ ^${category}_ ]]; then
        clean_name="${category}_${clean_name}"
    fi
    
    echo "${clean_name}.png"
}

# Function to convert single image to PNG
convert_image_to_png() {
    local input_file="$1"
    local output_file="$2"
    local quality="${3:-95}"
    
    log "Converting: $(basename "$input_file") -> $(basename "$output_file")"
    
    # Backup original file
    local backup_path="$BACKUP_DIR/$(basename "$input_file")"
    if [ ! -f "$backup_path" ]; then
        cp "$input_file" "$backup_path"
        log "Backed up original to: $backup_path"
    fi
    
    # Convert using ImageMagick with optimization
    if command -v convert &> /dev/null; then
        if convert "$input_file" -quality "$quality" -strip -define png:compression-level=9 "$output_file"; then
            local input_size=$(du -h "$input_file" | cut -f1)
            local output_size=$(du -h "$output_file" | cut -f1)
            success "Converted $(basename "$input_file") [$input_size -> $output_size]"
            return 0
        else
            error "ImageMagick conversion failed for: $input_file"
            return 1
        fi
    # Fallback to sips on macOS
    elif [[ "$OSTYPE" == "darwin"* ]] && command -v sips &> /dev/null; then
        if sips -s format png -s formatOptions 100 "$input_file" --out "$output_file" &>/dev/null; then
            success "Converted $(basename "$input_file") using sips"
            return 0
        else
            error "sips conversion failed for: $input_file"
            return 1
        fi
    else
        error "No suitable image converter available"
        return 1
    fi
}

# Function to extract video thumbnails
extract_video_thumbnail() {
    local video_file="$1"
    local output_file="$2"
    local timestamp="${3:-00:00:05}"
    
    if ! command -v ffmpeg &> /dev/null; then
        warning "ffmpeg not available - skipping video thumbnail: $(basename "$video_file")"
        return 1
    fi
    
    log "Extracting thumbnail from video: $(basename "$video_file")"
    
    if ffmpeg -i "$video_file" -ss "$timestamp" -vframes 1 -y -q:v 2 "$output_file" &>/dev/null; then
        success "Extracted thumbnail from: $(basename "$video_file")"
        return 0
    else
        error "Failed to extract thumbnail from: $video_file"
        return 1
    fi
}

# Function to optimize PNG files
optimize_png() {
    local png_file="$1"
    
    # Use optipng if available for additional compression
    if command -v optipng &> /dev/null; then
        log "Optimizing PNG: $(basename "$png_file")"
        if optipng -quiet -o2 "$png_file" 2>/dev/null; then
            success "Optimized: $(basename "$png_file")"
        else
            warning "PNG optimization failed for: $(basename "$png_file")"
        fi
    fi
}

# Function to create image inventory
create_image_inventory() {
    log "Creating image inventory..."
    
    local inventory_file="$MEDIA_DIR/image-inventory.md"
    
    cat > "$inventory_file" << 'EOF'
# LiveEventOps - Image Inventory

This document provides an inventory of all images converted to PNG format for documentation.

## Conversion Summary

EOF
    
    echo "**Conversion Date:** $(date)" >> "$inventory_file"
    echo "**Total Images Converted:** $(find "$CONVERTED_DIR" -name "*.png" | wc -l)" >> "$inventory_file"
    echo "" >> "$inventory_file"
    
    # Add inventory by category
    local categories=("screenshots" "diagrams" "demos" "ui" "architecture" "monitoring" "general")
    
    for category in "${categories[@]}"; do
        local category_dir="$CONVERTED_DIR/$category"
        if [ -d "$category_dir" ] && [ "$(ls -A "$category_dir" 2>/dev/null)" ]; then
            echo "## $category" >> "$inventory_file"
            echo "" >> "$inventory_file"
            
            find "$category_dir" -name "*.png" | sort | while read -r png_file; do
                local filename=$(basename "$png_file")
                local filesize=$(du -h "$png_file" | cut -f1)
                local dimensions=$(identify -format "%wx%h" "$png_file" 2>/dev/null || echo "Unknown")
                
                echo "- **$filename** - Size: $filesize, Dimensions: $dimensions" >> "$inventory_file"
            done
            
            echo "" >> "$inventory_file"
        fi
    done
    
    # Add usage examples
    cat >> "$inventory_file" << 'EOF'
## Usage in Documentation

To use these images in markdown documentation:

```markdown
![Screenshot Description](media/png/screenshots/screenshot_name.png)
![Diagram Description](media/png/diagrams/diagram_name.png)
![Demo Description](media/png/demos/demo_name.png)
```

## File Organization

```
media/
├── png/                    # Converted PNG files
│   ├── screenshots/        # Application screenshots
│   ├── diagrams/          # Architecture and flow diagrams
│   ├── demos/             # Demo and example images
│   ├── ui/                # User interface screenshots
│   ├── architecture/      # System architecture diagrams
│   ├── monitoring/        # Monitoring and dashboard screenshots
│   └── general/           # Other images
├── originals/             # Backup of original image files
└── image-inventory.md     # This inventory file
```

## Image Standards

- **Format:** PNG with compression level 9
- **Quality:** High quality (95% for converted images)
- **Naming:** Descriptive names with category prefixes
- **Organization:** Categorized by purpose and content type
- **Optimization:** Additional compression applied where possible

---

*Generated automatically by convert-images-to-png.sh*
EOF

    success "Created image inventory: $inventory_file"
}

# Function to generate sample images for testing
generate_sample_images() {
    log "Generating sample images for testing..."
    
    # Create sample images if media directory is empty
    local sample_dir="$MEDIA_DIR/samples"
    mkdir -p "$sample_dir"
    
    # Generate test images using ImageMagick
    if command -v convert &> /dev/null; then
        # Architecture diagram sample
        convert -size 800x600 xc:white \
            -font Arial -pointsize 24 -fill black \
            -gravity center -annotate +0-100 "LiveEventOps Architecture" \
            -pointsize 16 -annotate +0-50 "Azure Infrastructure Diagram" \
            -pointsize 12 -annotate +0+50 "Management VM -> Network -> Storage" \
            -stroke black -strokewidth 2 -fill none \
            -draw "rectangle 100,200 300,350" \
            -draw "rectangle 350,200 550,350" \
            -draw "rectangle 600,200 700,350" \
            "$sample_dir/architecture_diagram.jpg"
        
        # Screenshot sample  
        convert -size 1024x768 xc:'#f0f0f0' \
            -font Arial -pointsize 20 -fill '#333333' \
            -gravity northwest -annotate +20+20 "Azure Portal Dashboard" \
            -pointsize 14 -annotate +20+60 "Resource Group: liveeventops-rg" \
            -stroke '#0078d4' -strokewidth 2 -fill '#0078d4' \
            -draw "rectangle 20,100 1000,700" \
            -fill white -draw "rectangle 40,120 980,680" \
            -fill black -pointsize 12 -annotate +50+150 "Virtual Machines: 3 running" \
            -annotate +50+180 "Storage Accounts: 2 active" \
            -annotate +50+210 "Key Vault: 1 configured" \
            "$sample_dir/azure_portal_screenshot.bmp"
        
        # Monitoring dashboard sample
        convert -size 1200x800 xc:black \
            -font Arial -pointsize 18 -fill green \
            -gravity northwest -annotate +20+20 "LiveEventOps Monitoring Dashboard" \
            -pointsize 12 -fill white \
            -annotate +20+60 "System Status: All Services Operational" \
            -fill lime -annotate +20+100 "CPU Usage: 45%" \
            -fill cyan -annotate +20+130 "Memory Usage: 62%" \
            -fill yellow -annotate +20+160 "Disk Usage: 34%" \
            -stroke green -strokewidth 1 \
            -draw "line 100,200 1100,200" \
            -draw "line 100,200 100,700" \
            "$sample_dir/monitoring_dashboard.gif"
        
        success "Generated sample images for testing"
    else
        warning "ImageMagick not available - cannot generate sample images"
    fi
}

# Function to display conversion summary
display_summary() {
    local total_converted="$1"
    local total_failed="$2"
    local total_skipped="$3"
    
    echo ""
    echo "🖼️  Image Conversion Complete!"
    echo "================================"
    echo ""
    log "Conversion Summary:"
    echo "  ✅ Successfully converted: $total_converted images"
    echo "  ❌ Failed conversions: $total_failed images"
    echo "  ⏭️  Skipped (already PNG): $total_skipped images"
    echo ""
    
    if [ -d "$CONVERTED_DIR" ]; then
        log "Converted images location:"
        echo "  📁 $CONVERTED_DIR"
        echo ""
        
        log "Category breakdown:"
        local categories=("screenshots" "diagrams" "demos" "ui" "architecture" "monitoring")
        for category in "${categories[@]}"; do
            local count=$(find "$CONVERTED_DIR/$category" -name "*.png" 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                echo "  📂 $category: $count images"
            fi
        done
    fi
    
    echo ""
    log "Usage instructions:"
    echo "  1. Use images in documentation with:"
    echo "     ![Description](media/png/category/image_name.png)"
    echo "  2. Original images backed up to: $BACKUP_DIR"
    echo "  3. View complete inventory: $MEDIA_DIR/image-inventory.md"
    echo ""
    
    if [ "$total_failed" -gt 0 ]; then
        warning "Some conversions failed. Check the log file: $LOG_FILE"
    fi
    
    success "Image conversion workflow completed!"
}

# Main conversion function
main_conversion() {
    local convert_samples="${1:-false}"
    
    echo "🖼️  LiveEventOps - Image Conversion to PNG"
    echo "=========================================="
    echo ""
    
    # Initialize log file
    echo "LiveEventOps Image Conversion Log - $(date)" > "$LOG_FILE"
    
    check_dependencies
    setup_directories
    
    # Generate sample images if requested or if media is empty
    if [ "$convert_samples" = "true" ] || [ -z "$(ls -A "$MEDIA_DIR" 2>/dev/null | grep -v "png\|originals\|conversion.log")" ]; then
        generate_sample_images
    fi
    
    # Find all image files
    local image_files=($(find_image_files))
    
    if [ ${#image_files[@]} -eq 0 ]; then
        warning "No image files found in $MEDIA_DIR"
        warning "Use --generate-samples to create test images"
        create_image_inventory
        return 0
    fi
    
    log "Found ${#image_files[@]} image files to process"
    
    # Conversion counters
    local total_converted=0
    local total_failed=0
    local total_skipped=0
    
    # Process each image file
    for image_file in "${image_files[@]}"; do
        # Skip if already PNG
        if [[ "$image_file" =~ \.png$ ]]; then
            log "Skipping PNG file: $(basename "$image_file")"
            ((total_skipped++))
            continue
        fi
        
        # Categorize image
        local category=$(categorize_image "$image_file")
        local png_filename=$(generate_png_filename "$image_file" "$category")
        local output_path="$CONVERTED_DIR/$category/$png_filename"
        
        # Skip if already converted
        if [ -f "$output_path" ]; then
            log "Already exists: $(basename "$output_path")"
            ((total_skipped++))
            continue
        fi
        
        # Convert the image
        if convert_image_to_png "$image_file" "$output_path" 95; then
            optimize_png "$output_path"
            ((total_converted++))
        else
            ((total_failed++))
        fi
    done
    
    # Process video files for thumbnails
    local video_files=($(find "$MEDIA_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" \) 2>/dev/null))
    
    for video_file in "${video_files[@]}"; do
        if [[ "$video_file" != *"/originals/"* ]] && [[ "$video_file" != *"/png/"* ]]; then
            local category="demos"
            local thumbnail_name="video_thumbnail_$(basename "${video_file%.*}").png"
            local thumbnail_path="$CONVERTED_DIR/$category/$thumbnail_name"
            
            if [ ! -f "$thumbnail_path" ]; then
                if extract_video_thumbnail "$video_file" "$thumbnail_path"; then
                    optimize_png "$thumbnail_path"
                    ((total_converted++))
                fi
            fi
        fi
    done
    
    create_image_inventory
    display_summary "$total_converted" "$total_failed" "$total_skipped"
}

# Command line argument handling
show_help() {
    cat << EOF
LiveEventOps Image Conversion Script

Usage: $0 [OPTIONS]

Convert all demo images/screenshots in the media folder to PNG format for documentation.

OPTIONS:
    --help                  Show this help message
    --generate-samples      Generate sample images for testing
    --check-deps           Check dependencies only
    --inventory-only       Create inventory without conversion
    --clean               Clean up converted images and start fresh

EXAMPLES:
    $0                     # Convert all images in media folder
    $0 --generate-samples  # Generate test images and convert them
    $0 --check-deps        # Verify required tools are installed
    $0 --clean             # Remove converted images and start over

REQUIREMENTS:
    - ImageMagick (convert command)
    - Optional: ffmpeg (for video thumbnails)
    - Optional: optipng (for PNG optimization)

OUTPUT:
    - Original images backed up to: media/originals/
    - PNG images organized in: media/png/
    - Inventory file created: media/image-inventory.md
    - Conversion log: media/conversion.log

EOF
}

# Main script execution
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --generate-samples)
        main_conversion true
        ;;
    --check-deps)
        check_dependencies
        exit 0
        ;;
    --inventory-only)
        setup_directories
        create_image_inventory
        exit 0
        ;;
    --clean)
        echo "🧹 Cleaning up converted images..."
        rm -rf "$MEDIA_DIR/png" "$MEDIA_DIR/originals" "$MEDIA_DIR/conversion.log" "$MEDIA_DIR/image-inventory.md"
        echo "✅ Cleanup complete"
        exit 0
        ;;
    "")
        main_conversion false
        ;;
    *)
        error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
