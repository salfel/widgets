package main

Color :: distinct [4]f32

BLACK :: Color{0, 0, 0, 1}
WHITE :: Color{1, 1, 1, 1}

RED :: Color{1, 0, 0, 1}
YELLOW :: Color{1, 1, 0, 1}
GREEN :: Color{0, 1, 0, 1}
CYAN :: Color{0, 1, 1, 1}
BLUE :: Color{0, 0, 1, 1}
MAGENTA :: Color{1, 0, 1, 1}

Side :: enum {
	Top,
	Right,
	Bottom,
	Left,
}
Sides :: [Side]f32

Property :: enum {
	Width,
	Height,
	Color,
	Background,
	Padding,
	Margin,
	Border,
	Rounding,
	Font_Size,
}

Value :: union {
	Color,
	f32,
	Sides,
	Border,
}

Style :: map[Property]Value

Text_Style :: struct {
	font_size: f32,
	color:     Color,
}

DEFAULT_TEXT_STYLE :: Text_Style {
	color     = BLACK,
	font_size = 24,
}

Border :: struct {
	width: f32,
	color: Color,
}
