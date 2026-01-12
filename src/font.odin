package main

import "base:runtime"
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
	content, font_name: cstring,
	font_size:          f64,
	allocator:          runtime.Allocator,

	// external
	size:               [2]i32,
	min_width:          i32,
	ink_rect:           Bounds(i32),
	stride:             i32,
	wrap:               Wrap,
}

Wrap :: pango.WrapMode

font_make :: proc(content, font_name: string, font_size: f64, allocator := context.allocator) -> (font: Font) {
	font.allocator = allocator
	font.content = strings.clone_to_cstring(content, allocator)
	font.font_name = strings.clone_to_cstring(font_name, allocator)
	font.font_size = font_size
	font.wrap = .WRAP_WORD

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

font_set_size :: proc(font: ^Font, font_size: f64) {
	cairo.destroy(font.cr)
	cairo.surface_destroy(font.surface)
	gobj.object_unref(font.layout)

	font.font_size = font_size

	font_calc_rect(font)
	font_create_surface(font)
}

font_set_width :: proc(font: ^Font, width: i32) {
	cairo.destroy(font.cr)
	cairo.surface_destroy(font.surface)
	gobj.object_unref(font.layout)

	font_calc_rect(font, width)
	font_create_surface(font)
}

font_set_wrap :: proc(font: ^Font, wrap: Wrap) {
	cairo.destroy(font.cr)
	cairo.surface_destroy(font.surface)
	gobj.object_unref(font.layout)

	font.wrap = wrap

	font_calc_rect(font)
	font_create_surface(font)
}

font_create_surface :: proc(font: ^Font) {
	font.surface = cairo.image_surface_create(.A8, font.ink_rect.size.x, font.ink_rect.size.y)
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

font_get_bitmap :: proc(font: ^Font, allocator := context.allocator) -> ^u8 {
	cairo.set_source_rgb(font.cr, 1.0, 1.0, 1.0)

	cairo.translate(font.cr, f64(-font.ink_rect.position.x), f64(-font.ink_rect.position.y))
	cairo.move_to(font.cr, 0, 0)
	pangocairo.show_layout(font.cr, font.layout)

	cairo.surface_flush(font.surface)

	cairo_data := cairo.image_surface_get_data(font.surface)
	font.stride = cairo.image_surface_get_stride(font.surface)

	return cairo_data
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
	pango.layout_set_wrap(layout, font.wrap)

	font.min_width = font_get_min_width(layout)

	ink_rect, log_rect: pango.Rectangle
	pango.layout_get_pixel_extents(layout, &ink_rect, &log_rect)

	font.size = {log_rect.width, log_rect.height}
	font.ink_rect = {
		size     = {ink_rect.width, ink_rect.height},
		position = {ink_rect.x, ink_rect.y},
	}
}


font_get_min_width :: proc(layout: ^pango.Layout) -> i32 {
	org_width := pango.layout_get_width(layout)
	org_wrap := pango.layout_get_wrap(layout)

	pango.layout_set_width(layout, 0)

	min_width: i32
	pango.layout_get_pixel_size(layout, &min_width, nil)

	pango.layout_set_width(layout, org_width)

	return min_width
}

font_get_cursor_pos :: proc(font: ^Font, offset: i32, allocator := context.allocator) -> ([2]i32, i32) {
	cursor: pango.Rectangle
	pango.layout_get_cursor_pos(font.layout, offset, &cursor, nil)

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
