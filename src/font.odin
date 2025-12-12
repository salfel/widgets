package main

import "base:runtime"
import "core:slice"
import "core:strings"
import "lib:fontconfig"
import "lib:gtk/cairo"
import gobj "lib:gtk/glib/gobject"
import "lib:gtk/pango"
import "lib:gtk/pango/pangocairo"

Font :: struct {
	// internal
	layout:             ^pango.Layout,
	surface:            ^cairo.surface_t,
	cr:                 ^cairo.context_t,
	ink_rect:           pango.Rectangle,
	content, font_name: cstring,
	font_size:          f64,
	allocator:          runtime.Allocator,

	// external
	size:               [2]i32,
	min_width:          i32,
}

font_make :: proc(content, font_name: string, font_size: f64, allocator := context.allocator) -> (font: Font) {
	font.allocator = allocator
	font.content = strings.clone_to_cstring(content, allocator)
	font.font_name = strings.clone_to_cstring(font_name, allocator)
	font.font_size = font_size

	font_calc_rect(&font)
	font_create_surface(&font)

	return
}

font_destroy :: proc(font: ^Font) {
	delete(font.content, font.allocator)
	delete(font.font_name, font.allocator)

	cairo.destroy(font.cr)
	cairo.surface_destroy(font.surface)
	gobj.object_unref(font.layout)
}

font_set_content :: proc(font: ^Font, content: string) {
	delete(font.content, font.allocator)
	cairo.destroy(font.cr)
	cairo.surface_destroy(font.surface)
	gobj.object_unref(font.layout)

	font.content = strings.clone_to_cstring(content, font.allocator)

	font_calc_rect(font)
	font_create_surface(font)
}

font_create_surface :: proc(font: ^Font) {
	font.surface = cairo.image_surface_create(.A8, font.size.x, font.size.y)
	font.cr = cairo.create(font.surface)

	cairo.set_source_rgba(font.cr, 0.0, 0.0, 0.0, 0.0)
	cairo.paint(font.cr)

	font.layout = pangocairo.create_layout(font.cr)

	font_desc := pango.font_description_from_string(font.font_name)
	pango.font_description_set_absolute_size(font_desc, font.font_size * pango.SCALE)
	pango.layout_set_font_description(font.layout, font_desc)
	pango.font_description_free(font_desc)

	pango.layout_set_text(font.layout, font.content, -1)

	pango.layout_set_width(font.layout, font.size.x * pango.SCALE)
	pango.layout_set_alignment(font.layout, .ALIGN_LEFT)
}

font_get_bitmap :: proc(font: ^Font, allocator := context.allocator) -> []u8 {
	cairo.set_source_rgb(font.cr, 1.0, 1.0, 1.0)

	cairo.move_to(font.cr, 0, 0)
	cairo.translate(font.cr, f64(-font.ink_rect.x), f64(-font.ink_rect.y))
	pangocairo.show_layout(font.cr, font.layout)

	cairo.surface_flush(font.surface)

	cairo_data := cairo.image_surface_get_data(font.surface)
	stride := cairo.image_surface_get_stride(font.surface)
	bmp := slice.from_ptr(cairo_data, int(stride * font.size.y))

	bitmap: []u8

	if stride == font.size.x {
		bitmap = slice.clone(bmp)
	} else {
		bitmap = make([]u8, font.size.x * font.size.y, allocator)
		for i in 0 ..< font.size.y {
			src_offset := i * stride
			dst_offset := i * font.size.x

			copy(bitmap[dst_offset:dst_offset + font.size.x], bmp[src_offset:src_offset + font.size.x])
		}
	}

	return bitmap
}

font_calc_rect :: proc(font: ^Font, width: i32 = -1, allocator := context.allocator) {
	surface := cairo.image_surface_create(.A8, 1, 1)
	cr := cairo.create(surface)
	defer cairo.surface_destroy(surface)
	defer cairo.destroy(cr)

	layout := pangocairo.create_layout(cr)
	defer gobj.object_unref(layout)

	font_desc := pango.font_description_from_string(font.font_name)
	pango.font_description_set_absolute_size(font_desc, font.font_size * pango.SCALE)
	pango.layout_set_font_description(layout, font_desc)
	pango.font_description_free(font_desc)

	pango.layout_set_text(layout, font.content, -1)
	pango.layout_set_width(layout, width * pango.SCALE if width > 0 else -1)
	pango.layout_set_wrap(layout, .WRAP_WORD)

	font.min_width = font_get_min_width(layout)

	log_rect: pango.Rectangle
	pango.layout_get_pixel_extents(layout, &font.ink_rect, &log_rect)

	font.size = {log_rect.width, log_rect.height}
}


font_get_min_width :: proc(layout: ^pango.Layout) -> i32 {
	org_width := pango.layout_get_width(layout)
	org_wrap := pango.layout_get_wrap(layout)

	pango.layout_set_width(layout, 0)
	pango.layout_set_wrap(layout, .WRAP_WORD)

	min_width: i32
	pango.layout_get_pixel_size(layout, &min_width, nil)

	pango.layout_set_width(layout, org_width)
	pango.layout_set_wrap(layout, org_wrap)

	return min_width
}

font_get_cursor_pos :: proc(font: ^Font, offset_in: i32, allocator := context.allocator) -> ([2]i32, i32) {
	cursor: pango.Rectangle
	pango.layout_get_cursor_pos(font.layout, offset_in, &cursor, nil)

	return {cursor.x, cursor.y} / pango.SCALE, cursor.height / pango.SCALE
}


@(init)
fontconfig_init :: proc "contextless" () {
	fontconfig.Init()
}

@(fini)
fontconfig_fini :: proc "contextless" () {
	fontconfig.Fini()
}
