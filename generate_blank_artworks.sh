#!/bin/bash

# Constants for output 1
BG1_WIDTH=1290
BG1_HEIGHT=2796
SCALE_PERCENT_1=75
BOTTOM_MARGIN_1=20

# Constants for output 2
BG2_WIDTH=2064
BG2_HEIGHT=2752
SCALE_PERCENT_2=70
BOTTOM_MARGIN_2=20

# Shared settings
# Avoid grayscale colors
BG_COLOR="#ff00ff"             	
		
# Gradients: from black to dark-themed iOS palette-inspired colors
GRADIENTS=(
"#000000-#32B9D2"  # Teal Dark
"#000000-#0A84FF"  # Blue Dark
"#000000-#504BD2"  # Indigo Dark
"#000000-#AF50E6"  # Purple Dark
"#000000-#B40078"  # Magenta Dark
"#000000-#D13A32"  # Dark Coral
"#000000-#F02D5A"  # Pink Dark
"#000000-#A0320F"  # Rust Dark
"#000000-#FF8C05"  # Orange Dark
"#000000-#199650"  # Emerald Dark
)
	
	GRADIENT_ANGLE=0	

	# Border settings
	DRAW_BORDER=false
	BORDER_WIDTH=10

	JPG_QUALITY=95
	OUTPUT_DIR="artworks"
	TEMP_DIR="temp"
	SUBFOLDER_1="${BG1_WIDTH}x${BG1_HEIGHT}"
	SUBFOLDER_2="${BG2_WIDTH}x${BG2_HEIGHT}"

	script_dir="$(cd "$(dirname "$0")" && pwd)"
	screenshots1_dir="$script_dir/screenshots/$SUBFOLDER_1"
	screenshots2_dir="$script_dir/screenshots/$SUBFOLDER_2"
	output1_path="$script_dir/$OUTPUT_DIR/$SUBFOLDER_1"
	output2_path="$script_dir/$OUTPUT_DIR/$SUBFOLDER_2"
	temp_path="$script_dir/$TEMP_DIR"

	mkdir -p "$output1_path" "$output2_path" "$temp_path"

	# Check ImageMagick
	if ! command -v magick >/dev/null; then
		echo "❌ Error: ImageMagick not found. Install it with: brew install imagemagick"
		exit 1
	fi

	create_gradient() {
		local color_pair=$1   # Example: "#1e3c72-#2a5298"
		local width=$2        # e.g. 1290
		local height=$3       # e.g. 2796
		local angle=$4        # e.g. 135
		local output_path=$5

		IFS='-' read -r color1 color2 <<< "$color_pair"

		# Create vertical gradient
		magick -size 1x${height} gradient:"$color1"-"$color2" \
			-resize ${width}x${height}! \
				-distort SRT "$angle" \
					-gravity center -crop ${width}x${height}+0+0 +repage \
						"$output_path"
	}

	# Function to process one version
	generate_version() {
		local bg_width=$1
		local bg_height=$2
		local scale_percent=$3
		local output_dir=$4
		local input_file=$5
		local output_name=$6
		local gradient_index=$7
		local bottom_margin=$8

		resized="$temp_path/${output_name}_resized.png"
		rounded="$temp_path/${output_name}_rounded.png"
		shadow="$temp_path/${output_name}_shadow.png"
		merged="$temp_path/${output_name}_merged.png"
		mask="$temp_path/${output_name}_mask.png"
		bg_image="$temp_path/${output_name}_bg_${bg_width}x${bg_height}.png"
		final_output="$output_dir/${output_name}.jpg"

		# Resize
		magick "$input_file" -resize "${scale_percent}%" "$resized"

		# Get dimensions
		width=$(magick identify -format "%w" "$resized")
		height=$(magick identify -format "%h" "$resized")
		radius=$((width / 20))
		blur=$((width / 20))
		offset=0
	
		# Extract second color from gradient for border
		gradient="${GRADIENTS[$(( (gradient_index - 1) % ${#GRADIENTS[@]} ))]}"
		IFS='-' read -r _ border_color <<< "$gradient"

		# Rounded corners mask
		magick -size ${width}x${height} xc:none \
			-draw "roundrectangle 0,0 $((width-1)),$((height-1)) $radius,$radius" \
				"$mask"
		magick "$resized" "$mask" -compose DstIn -composite "$rounded"
	
		# Create a rounded border mask outline
		if [ "$DRAW_BORDER" = true ]; then
			border_margin=$((BORDER_WIDTH / 2))
			border_mask="$temp_path/${output_name}_border_mask.png"
			magick -size ${width}x${height} xc:none \
				-stroke "$border_color" -strokewidth "$BORDER_WIDTH" -fill none \
					-draw "roundrectangle $((border_margin - 2)),$((border_margin - 2)) $((width - border_margin + 2)),$((height - border_margin + 2)) $radius,$radius" \
						"$border_mask"

			# Combine border and rounded image
			with_border="$temp_path/${output_name}_with_border.png"
			magick "$rounded" "$border_mask" -compose over -composite "$with_border"
		else
			with_border="$rounded"
		fi

		# Shadow + merge
		magick \( "$with_border" -alpha on -background black -shadow "${blur}x${blur}+0+0" \) \
			\( "$with_border" -page +${offset}+${offset} \) \
				-background none -layers merge +repage "$merged"

		# Centered offsets
		img_width=$(magick identify -format "%w" "$merged")
		img_height=$(magick identify -format "%h" "$merged")
		margin=$(( (bg_width - img_width) / 2 ))
		offset_x=$margin
		# offset_y=$(( bg_height - img_height - margin ))
		offset_y=$(( bg_height - img_height - bottom_margin ))

		# Background and final output
		# magick -size ${bg_width}x${bg_height} xc:"$BG_COLOR" "$bg_image"

		# Create gradient background
		gradient="${GRADIENTS[$(( (gradient_index - 1) % ${#GRADIENTS[@]} ))]}"
		create_gradient "$gradient" "$bg_width" "$bg_height" "$GRADIENT_ANGLE" "$bg_image"

		magick "$bg_image" \
			\( "$merged" -page +${offset_x}+${offset_y} \) \
				-background none -layers merge +repage \
					-quality "$JPG_QUALITY" "$final_output"

		echo "✅ Created: $final_output"
	}

	# Define arrays for dual version parameters
	BG_WIDTHS=($BG1_WIDTH $BG2_WIDTH)
	BG_HEIGHTS=($BG1_HEIGHT $BG2_HEIGHT)
	SCALE_PERCENTS=($SCALE_PERCENT_1 $SCALE_PERCENT_2)
	BOTTOM_MARGINS=($BOTTOM_MARGIN_1 $BOTTOM_MARGIN_2)
	OUTPUT_PATHS=("$output1_path" "$output2_path")
	SCREENSHOTS_DIRS=("$screenshots1_dir" "$screenshots2_dir")

	for i in 0 1; do
		counter=1
		while IFS= read -r file; do
			[ -f "$file" ] || continue

			generate_version \
				"${BG_WIDTHS[$i]}" \
					"${BG_HEIGHTS[$i]}" \
						"${SCALE_PERCENTS[$i]}" \
							"${OUTPUT_PATHS[$i]}" \
								"$file" \
									"$counter" \
										"$counter" \
											"${BOTTOM_MARGINS[$i]}"

			counter=$((counter + 1))
		done < <(find "${SCREENSHOTS_DIRS[$i]}" -maxdepth 1 -iname "*.png" | sort -V)
	done

	# echo "🧪 Cleaning up temporary files..."
	# rm -rf "$temp_path"

	echo "🎯 All done! Check: $output1_path and $output2_path"
