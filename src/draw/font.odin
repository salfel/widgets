package draw

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
	width: i32 = -1,
	allocator := context.allocator,
) -> (
	bitmap: []u8,
	size: [2]i32,
	stride: i32,
	min_width: i32,
	ok := true,
) {
	content := strings.clone_to_cstring(content, allocator)
	defer delete(content, allocator)
	font := strings.clone_to_cstring(font, allocator)
	defer delete(font, allocator)

	ink_rect, log_rect: pango.Rectangle
	ink_rect, log_rect, min_width = font_get_size(content, font, height, width, allocator = allocator)

	size = {log_rect.width, log_rect.height}

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

	pango.layout_set_width(layout, log_rect.width * pango.SCALE)
	pango.layout_set_alignment(layout, .ALIGN_LEFT)

	cairo.set_source_rgb(cr, 1.0, 1.0, 1.0)

	cairo.move_to(cr, 0, 0)
	cairo.translate(cr, f64(-ink_rect.x), f64(-ink_rect.y))
	pangocairo.show_layout(cr, layout)

	cairo.surface_flush(surface)

	cairo_data := cairo.image_surface_get_data(surface)
	stride = cairo.image_surface_get_stride(surface)
	bmp := slice.from_ptr(cairo_data, int(stride * size.y))

	if stride == size.x {
		bitmap = slice.clone(bmp)
	} else {
		bitmap = make([]u8, size.x * size.y, allocator)
		for i in 0 ..< size.y {
			src_offset := i * stride
			dst_offset := i * size.x

			copy(bitmap[dst_offset:dst_offset + size.x], bmp[src_offset:src_offset + size.x])
		}
	}

	return
}

font_get_size :: proc(
	content: cstring,
	font: cstring,
	font_size: f64,
	width: i32 = -1,
	allocator := context.allocator,
) -> (
	pango.Rectangle,
	pango.Rectangle,
	i32,
) {
	surface := cairo.image_surface_create(.A8, 1, 1)
	cr := cairo.create(surface)
	defer cairo.surface_destroy(surface)
	defer cairo.destroy(cr)

	layout := pangocairo.create_layout(cr)
	defer gobj.object_unref(layout)

	font_desc := pango.font_description_from_string(font)
	pango.font_description_set_absolute_size(font_desc, font_size * pango.SCALE)
	pango.layout_set_font_description(layout, font_desc)
	pango.font_description_free(font_desc)

	pango.layout_set_text(layout, content, -1)
	pango.layout_set_width(layout, width * pango.SCALE if width > 0 else -1)
	pango.layout_set_wrap(layout, .WRAP_WORD)

	min_width := font_get_min_width(layout)

	ink_rect, log_rect: pango.Rectangle
	pango.layout_get_pixel_extents(layout, &ink_rect, &log_rect)

	return ink_rect, log_rect, min_width
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


@(init)
fontconfig_init :: proc "contextless" () {
	fontconfig.Init()
}

@(fini)
fontconfig_fini :: proc "contextless" () {
	fontconfig.Fini()
}
