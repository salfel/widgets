package main

Color :: distinct [4]f32

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

Border :: struct {
	width: f32,
	color: Color,
}
