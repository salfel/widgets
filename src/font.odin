package main

import "core:fmt"
import "core:math"
import "core:os"
import "vendor:stb/truetype"

font_bitmap_make :: proc(
	content: string,
	font: string,
	height: f32,
	allocator := context.allocator,
) -> (
	bitmap: []u8,
	size: [2]i32,
	ok := true,
) {
	buffer: []u8
	buffer, ok = os.read_entire_file_from_filename(font, allocator)
	defer delete(buffer)
	if !ok {
		fmt.eprintf("Failed to load %s", font)
		return nil, {}, false
	}

	info: truetype.fontinfo
	if err := truetype.InitFont(&info, raw_data(buffer), 0); !err {
		fmt.eprintln("Failed to init font")
		ok = false
	}

	scale := truetype.ScaleForPixelHeight(&info, height)

	ascent, descent, lineGap: i32
	truetype.GetFontVMetrics(&info, &ascent, &descent, &lineGap)

	ascent = i32(math.round((f32(ascent) * scale)))
	descent = i32(math.round((f32(descent) * scale)))

	width: i32 = 0
	max_ax: i32 = 0
	for char, i in content {
		ax, lsb: i32
		truetype.GetCodepointHMetrics(&info, char, &ax, &lsb)

		max_ax = math.max(max_ax, ax)

		kern: i32 = 0
		if i < len(content) - 1 {
			kern = truetype.GetCodepointKernAdvance(&info, char, rune(content[i + 1]))
		}

		width += i32(math.round(f32(ax + kern) * scale))
	}

	bitmap = make([]u8, width * (ascent - descent), allocator)
	temp_bitmap := make([]u8, max_ax * (ascent - descent), allocator)
	defer delete(temp_bitmap)

	x: i32 = 0
	for char, i in content {
		ax, lsb: i32
		truetype.GetCodepointHMetrics(&info, char, &ax, &lsb)

		cx1, cy1, cx2, cy2: i32
		truetype.GetCodepointBitmapBox(&info, char, scale, scale, &cx1, &cy1, &cx2, &cy2)

		c_width := cx2 - cx1
		c_height := cy2 - cy1

		truetype.MakeCodepointBitmap(&info, raw_data(temp_bitmap), c_width, c_height, max_ax, scale, scale, char)

		for gy: i32 = 0; gy < c_height; gy += 1 {
			for gx: i32 = 0; gx < c_width; gx += 1 {
				pixel := temp_bitmap[gy * max_ax + gx]
				if pixel == 0 do continue

				dest := &bitmap[(ascent + cy1 + gy) * width + x + i32(f32(lsb) * scale) + gx]

				dest^ = dest^ + pixel
			}
		}

		x += i32(math.round(f32(ax) * scale))

		if i < len(content) - 1 {
			kern := truetype.GetCodepointKernAdvance(&info, char, rune(content[i + 1]))
			x += i32(math.round(f32(kern) * scale))
		}
	}

	return bitmap, {width, ascent - descent}, true
}
