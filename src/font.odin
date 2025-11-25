package main

import "core:slice"
import "core:strings"
import "lib:fontconfig"
import "lib:gtk/cairo"
import gobj "lib:gtk/glib/gobject"
import "lib:gtk/pango"
import "lib:gtk/pango/pangocairo"

font_bitmap_make :: proc(
	content: string,
	font: string,
	height: f64,
	allocator := context.allocator,
) -> (
	bitmap: []u8,
	size: [2]i32,
	ok := true,
) {
	content := strings.clone_to_cstring(content, allocator)
	defer delete(content, allocator)
	font := strings.clone_to_cstring(font, allocator)
	defer delete(font, allocator)

	size = font_get_size(content, font, height, allocator)

	surface := cairo.image_surface_create(.A8, size.x, size.y)
	defer cairo.surface_destroy(surface)
	cr := cairo.create(surface)
	defer cairo.destroy(cr)

	cairo.set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0)
	cairo.paint(cr)

	layout := pangocairo.create_layout(cr)
	defer gobj.object_unref(layout)

	font_desc := pango.font_description_from_string(font)
	pango.font_description_set_absolute_size(font_desc, height * pango.SCALE)
	pango.layout_set_font_description(layout, font_desc)
	pango.font_description_free(font_desc)

	pango.layout_set_text(layout, content, -1)

	pango.layout_set_width(layout, size.x * pango.SCALE)
	pango.layout_set_alignment(layout, .ALIGN_LEFT)

	cairo.set_source_rgb(cr, 1.0, 1.0, 1.0)

	text_width, text_height: i32
	pango.layout_get_pixel_size(layout, &text_width, &text_height)
	y: f64 = f64(size.y - text_height) / 2

	cairo.move_to(cr, 0, y)
	pangocairo.show_layout(cr, layout)

	cairo.surface_flush(surface)

	cairo_data := cairo.image_surface_get_data(surface)
	bitmap = slice.clone(slice.from_ptr(cairo_data, int(size.x * size.y * 4)))

	return
}

font_get_size :: proc(content: cstring, font: cstring, height: f64, allocator := context.allocator) -> [2]i32 {
	surface := cairo.image_surface_create(.ARGB32, 1, 1)
	cr := cairo.create(surface)
	defer cairo.surface_destroy(surface)
	defer cairo.destroy(cr)

	layout := pangocairo.create_layout(cr)
	defer gobj.object_unref(layout)

	font_desc := pango.font_description_from_string(font)
	pango.font_description_set_absolute_size(font_desc, height * pango.SCALE)
	pango.layout_set_font_description(layout, font_desc)
	pango.font_description_free(font_desc)

	pango.layout_set_text(layout, content, -1)

	width, height: i32
	pango.layout_get_pixel_size(layout, &width, &height)

	return {width, height}
}


@(init)
fontconfig_init :: proc "contextless" () {
	fontconfig.Init()
}

@(fini)
fontconfig_fini :: proc "contextless" () {
	fontconfig.Fini()
}
