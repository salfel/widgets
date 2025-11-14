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

Layout_Style_Property :: enum {
	Width,
	Height,
	Padding,
	Margin,
	Border,
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

Text_Style :: struct {
	font_size: f32,
	color:     Color,
}

DEFAULT_TEXT_STYLE :: Text_Style {
	color     = BLACK,
	font_size = 24,
}

Image_Style :: struct {
	opacity: f32,
}

DEFAULT_IMAGE_STYLE :: Image_Style {
	opacity = 1,
}
