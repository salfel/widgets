package main

Color :: distinct [4]f32

TRANSPARENT :: Color{0, 0, 0, 0}
BLACK :: Color{0, 0, 0, 1}
WHITE :: Color{1, 1, 1, 1}

RED :: Color{1, 0, 0, 1}
YELLOW :: Color{1, 1, 0, 1}
GREEN :: Color{0, 1, 0, 1}
CYAN :: Color{0, 1, 1, 1}
BLUE :: Color{0, 0, 1, 1}
MAGENTA :: Color{1, 0, 1, 1}

Border :: struct {
	width: f32,
	color: Color,
}

Sides :: struct {
	left, right, top, bottom: f32,
}

sides_make :: proc {
	sides_make_single,
	sides_make_multiple,
	sides_make_axis,
}

sides_make_single :: proc(size: f32) -> Sides {
	return Sides{left = size, right = size, top = size, bottom = size}
}

sides_make_axis :: proc(horizontal, vertical: f32) -> Sides {
	return Sides{left = horizontal, right = horizontal, top = vertical, bottom = vertical}
}

sides_make_multiple :: proc(left, right, top, bottom: f32) -> Sides {
	return Sides{left = left, right = right, top = top, bottom = bottom}
}

sides_reflect_axis :: proc(sides: Sides, axis: Axis) -> Sides {
	if axis == .Horizontal {
		return sides
	}

	return Sides{left = sides.top, right = sides.bottom, top = sides.left, bottom = sides.right}
}

sides_axis :: proc(sides: Sides, axis: Axis) -> f32 {
	switch axis {
	case .Horizontal:
		return sides.left + sides.right
	case .Vertical:
		return sides.top + sides.bottom
	}

	return 0
}

DEFAULT_LAYOUT_STYLE :: Layout_Style {
	size    = {Layout_Constraint{0, 0}, Layout_Constraint{0, 0}},
	padding = {0, 0, 0, 0},
	margin  = {0, 0, 0, 0},
	border  = 0,
}

Box_Style :: struct {
	background:       Color,
	background_image: string,
	rounding:         f32,
	border:           Border,
}

DEFAULT_BOX_STYLE :: Box_Style {
	background       = TRANSPARENT,
	background_image = "",
	rounding         = 0,
	border           = {},
}

// Text_Style :: struct {
// 	font_size: f32,
// 	color:     Color,
// }
//
// DEFAULT_TEXT_STYLE :: Text_Style {
// 	color     = BLACK,
// 	font_size = 24,
// }
//
Image_Style :: struct {
	opacity: f32,
}

DEFAULT_IMAGE_STYLE :: Image_Style {
	opacity = 1,
}

// Sizing_Style :: struct {
// 	size:                                 [2]Layout_Constraint,
// 	padding, margin:                      Sides,
// 	border_width:                         f32,
// 	sizing_set_poperties, sizing_changed: bit_set[Sizing_Style_Property],
// }
// Sizing_Style_Property :: enum {
// 	Width,
// 	Height,
// 	Padding,
// 	Margin,
// 	Border_Width,
// }
//
// DEFAULT_SIZING_STYLE :: Sizing_Style{}
//
// sizing_style_set_width :: proc(sizing: ^Sizing_Style, width: Layout_Constraint) {
// 	sizing.size.x = width
// 	sizing.sizing_set_poperties += {.Width}
// 	sizing.sizing_changed += {.Width}
// }
//
// sizing_style_set_height :: proc(sizing: ^Sizing_Style, height: Layout_Constraint) {
// 	sizing.size.y = height
// 	sizing.sizing_set_poperties += {.Height}
// 	sizing.sizing_changed += {.Height}
// }
//
// sizing_style_set_padding :: proc(sizing: ^Sizing_Style, padding: Sides) {
// 	sizing.padding = padding
// 	sizing.sizing_set_poperties += {.Padding}
// 	sizing.sizing_changed += {.Padding}
// }
//
// sizing_style_set_margin :: proc(sizing: ^Sizing_Style, margin: Sides) {
// 	sizing.margin = margin
// 	sizing.sizing_set_poperties += {.Margin}
// 	sizing.sizing_changed += {.Margin}
// }
//
// sizing_style_set_border_width :: proc(sizing: ^Sizing_Style, border_width: f32) {
// 	sizing.border_width = border_width
// 	sizing.sizing_set_poperties += {.Border_Width}
// 	sizing.sizing_changed += {.Border_Width}
// }
//
// Rect_Style :: struct {
// 	using sizing:                     Sizing_Style,
// 	rounding:                         f32,
// 	background_color, border_color:   Color,
// 	rect_set_poperties, rect_changed: bit_set[Rect_Style_Property],
// }
// Rect_Style_Property :: enum {
// 	Background_Color,
// 	Border_Color,
// }
//
// DEFAULT_RECT_STYLE :: Rect_Style {
// 	sizing = DEFAULT_SIZING_STYLE,
// }
//
// rect_style_set_width :: sizing_style_set_width
// rect_style_set_height :: sizing_style_set_height
// rect_style_set_padding :: sizing_style_set_padding
// rect_style_set_margin :: sizing_style_set_margin
// rect_style_set_border_width :: sizing_style_set_border_width
//
// rect_style_set_background_color :: proc(rect: ^Rect_Style, color: Color) {
// 	rect.background_color = color
// 	rect.rect_set_poperties += {.Background_Color}
// 	rect.rect_changed += {.Background_Color}
// }
//
// rect_style_set_border_color :: proc(rect: ^Rect_Style, color: Color) {
// 	rect.border_color = color
// 	rect.rect_set_poperties += {.Border_Color}
// 	rect.rect_changed += {.Border_Color}
// }
