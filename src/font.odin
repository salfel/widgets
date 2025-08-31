package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "vendor:stb/image"
import "vendor:stb/truetype"

Glyph_Repository :: struct {
	font_configs: [dynamic]^Font_Config,
}

glyph_repository_make :: proc(allocator := context.allocator) -> (glyph_repository: Glyph_Repository) {
	glyph_repository.font_configs = make([dynamic]^Font_Config, allocator)

	return
}

glyph_repository_destroy :: proc(glyph_repository: ^Glyph_Repository, allocator := context.allocator) {
	for &font_config in glyph_repository.font_configs {
		font_config_destroy(font_config, allocator)
	}

	delete(glyph_repository.font_configs)
}

Font_Config :: struct {
	name:                     string,
	size:                     f32,
	buffer:                   []u8,
	info:                     truetype.fontinfo,
	scale:                    f32,
	ascent, descent, lineGap: i32,
	glyphs:                   map[rune]Glyph,
}

Glyph :: struct {
	bitmap:        []u8,
	ax, lsb, kern: i32,
	width, height: f32,
	font_config:   ^Font_Config,
}

font_config_make :: proc(
	filename: string,
	size: f32,
	allocator := context.allocator,
) -> (
	font_config: ^Font_Config,
	ok := true,
) {
	for font_config in app_state.glyph_repository.font_configs {
		if font_config.name == filename && font_config.size == size {
			return font_config, true
		}
	}

	font_config = new(Font_Config, allocator)

	font_config.name = filename
	font_config.size = size
	font_config.glyphs = make(map[rune]Glyph, allocator)

	font_config.buffer, ok = os.read_entire_file_from_filename(filename, allocator)
	if !ok {
		fmt.eprintln("Failed to load font.ttf")
		return nil, false
	}

	if err := truetype.InitFont(&font_config.info, raw_data(font_config.buffer), 0); !err {
		fmt.eprintln("Failed to init font")
		ok = false
	}

	font_config.scale = truetype.ScaleForPixelHeight(&font_config.info, size)

	truetype.GetFontVMetrics(&font_config.info, &font_config.ascent, &font_config.descent, &font_config.lineGap)

	font_config.ascent = i32(math.round((f32(font_config.ascent) * font_config.scale)))
	font_config.descent = i32(math.round((f32(font_config.descent) * font_config.scale)))

	append(&app_state.glyph_repository.font_configs, font_config)

	return
}

font_config_destroy :: proc(font_config: ^Font_Config, allocator := context.allocator) {
	for _, &glyph in font_config.glyphs {
		glyph_destroy(&glyph, allocator)
	}

	delete(font_config.glyphs)
	delete(font_config.buffer, allocator)
	free(font_config, allocator)
}

glyph_make :: proc(
	font_config: ^Font_Config,
	char: rune,
	next: rune,
	allocator := context.allocator,
) -> (
	glyph: Glyph,
) {
	if _, ok := font_config.glyphs[char]; ok {
		return font_config.glyphs[char]
	}

	glyph.font_config = font_config

	truetype.GetCodepointHMetrics(&font_config.info, char, &glyph.ax, &glyph.lsb)

	glyph.ax = i32(math.round((f32(glyph.ax) * font_config.scale)))
	glyph.lsb = i32(math.round((f32(glyph.lsb) * font_config.scale)))

	cx1, cy1, cx2, cy2: i32
	truetype.GetCodepointBitmapBox(
		&font_config.info,
		char,
		font_config.scale,
		font_config.scale,
		&cx1,
		&cy1,
		&cx2,
		&cy2,
	)

	glyph.width = f32(cx2 - cx1)
	glyph.height = f32(cy2 - cy1)

	glyph.bitmap = make([]u8, i32(glyph.width * glyph.height), allocator)

	truetype.MakeCodepointBitmap(
		&font_config.info,
		raw_data(glyph.bitmap),
		cx2 - cx1,
		cy2 - cy1,
		i32(glyph.width),
		font_config.scale,
		font_config.scale,
		rune(char),
	)

	font_config.glyphs[char] = glyph

	if next != 0 {
		glyph.kern = truetype.GetCodepointKernAdvance(&font_config.info, char, next)
		glyph.kern = i32(math.round((f32(glyph.kern) * font_config.scale)))
	}

	return
}

glyph_destroy :: proc(glyph: ^Glyph, allocator := context.allocator) {
	delete(glyph.bitmap, allocator)
}
