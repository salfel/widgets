package main

import "core:log"
import "core:math"
import "core:testing"

UNDEFINED :: -1

Edges :: struct {
	left:   f32,
	right:  f32,
	top:    f32,
	bottom: f32,
}

edges_make_single :: proc(size: f32) -> Edges {
	return Edges{left = size, right = size, top = size, bottom = size}
}

edges_make :: proc {
	edges_make_single,
}

Layout_Type :: enum {
	Block,
	Box,
}

Layout :: struct {
	type:     Layout_Type,
	width:    f32,
	height:   f32,
	border:   Edges,
	padding:  Edges,
	margin:   Edges,
	children: [dynamic]^Layout,

	// result
	result:   struct {
		size:     [2]f32,
		position: [2]f32,
	},
}

layout_make :: proc(allocator := context.allocator) -> Layout {
	return Layout {
		type = .Block,
		width = UNDEFINED,
		height = UNDEFINED,
		border = edges_make(0),
		padding = edges_make(0),
		margin = edges_make(0),
		result = {size = {0, 0}, position = {0, 0}},
		children = make([dynamic]^Layout, allocator),
	}
}

layout_destroy :: proc(layout: ^Layout) {
	delete(layout.children)
}

layout_compute :: proc(layout: ^Layout, available: f32 = 0) {
	if layout.type == .Box {
		children_size := [2]f32{0, 0}
		for &child in layout.children {
			layout_compute(child)

			children_size.x += child.result.size.x + child.margin.left + child.margin.right
			children_size.y = math.max(children_size.y, child.result.size.y + child.margin.top + child.margin.bottom)
		}

		if layout.width == UNDEFINED {
			layout.result.size.x =
				children_size.x + layout.padding.left + layout.padding.right + layout.border.left + layout.border.right
		} else do layout.result.size.x = layout.width + layout.border.left + layout.border.right

		if layout.height == UNDEFINED {
			layout.result.size.y =
				children_size.y + layout.padding.top + layout.padding.bottom + layout.border.top + layout.border.bottom
		} else do layout.result.size.y = layout.height + layout.border.top + layout.border.bottom

		return
	}

	layout.result.size.x = available - layout.margin.left - layout.margin.right
	layout.result.size.y = layout.height + layout.border.top + layout.border.bottom

	children_height := layout.border.top + layout.border.bottom + layout.padding.top + layout.padding.bottom

	box_height: f32 = 0
	for &child in layout.children {
		layout_compute(
			child,
			layout.result.size.x -
			layout.padding.left -
			layout.padding.right -
			layout.border.left -
			layout.border.right,
		)

		child_height := child.result.size.y + child.margin.top + child.margin.bottom

		if child.type == .Box {
			if child_height > box_height {
				children_height += child_height - box_height
				box_height = child_height
			}
		} else {
			children_height += child_height
		}
	}

	layout.result.size.y = math.max(layout.result.size.y, children_height)
}

layout_arrange :: proc(layout: ^Layout, offset: [2]f32 = {0, 0}) {
	parent_offset := [2]f32{offset.x + layout.margin.left, offset.y + layout.margin.top}
	layout.result.position = parent_offset
	parent_offset.x += layout.padding.left + layout.border.left
	parent_offset.y += layout.padding.top + layout.border.top

	offset := parent_offset

	for &child in layout.children {
		layout_arrange(child, offset)
		if child.type == .Box {
			offset.x += child.result.size.x + child.margin.left + child.margin.right
		} else {
			offset.y += child.result.size.y + child.margin.bottom
			offset.x = parent_offset.x
		}
	}
}

@(test)
test_layout_compute_block :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)
	child1 := layout_make()
	child2 := layout_make()

	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.type = .Block
	parent.height = 100
	parent.padding.left = 30
	parent.margin.right = 100
	parent.padding.top = 10

	child1.type = .Block
	child1.height = 100
	child1.margin.left = 10
	child1.margin.right = 10

	child2.type = .Block
	child2.height = 200
	child2.border.left = 10

	layout_compute(&parent, 500)

	testing.expect(t, parent.result.size.x == 400)
	testing.expect(t, parent.result.size.y == 310)

	testing.expect(t, child1.result.size.x == 350)
	testing.expect(t, child1.result.size.y == 100)

	testing.expect(t, child2.result.size.x == 370)
	testing.expect(t, child2.result.size.y == 200)
}

@(test)
test_layout_compute_box :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)
	child1 := layout_make()
	child2 := layout_make()

	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.type = .Box
	parent.padding.left = 30
	parent.margin.right = 100
	parent.padding.top = 10

	child1.type = .Box
	child1.width = 100
	child1.height = 100
	child1.margin.left = 10
	child1.margin.right = 10

	child2.type = .Box
	child2.width = 200
	child2.height = 200
	child2.border.left = 10

	layout_compute(&parent)

	testing.expect(t, parent.result.size.x == 360)
	testing.expect(t, parent.result.size.y == 210)

	testing.expect(t, child1.result.size.x == 100)
	testing.expect(t, child1.result.size.y == 100)

	testing.expect(t, child2.result.size.x == 210)
	testing.expect(t, child2.result.size.y == 200)
}

@(test)
test_layout_arrange :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)
	child1 := layout_make()
	child2 := layout_make()

	child3 := layout_make()
	child4 := layout_make()

	append(&child2.children, &child3)
	append(&child2.children, &child4)
	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.type = .Block
	parent.height = 100
	parent.padding.left = 30
	parent.margin.right = 100
	parent.padding.top = 10

	child1.type = .Block
	child1.height = 100
	child1.margin.left = 10
	child1.margin.right = 10
	child1.border.left = 10
	child1.border.top = 10

	child2.type = .Block
	child2.margin.left = 10
	child2.border.left = 10
	child2.padding.left = 30
	child2.border.top = 10

	child3.type = .Box
	child3.width = 100
	child3.height = 100
	child3.border.left = 10

	child4.type = .Box
	child4.width = 100
	child4.height = 150
	child4.margin.left = 10

	layout_compute(&parent, 500)
	layout_arrange(&parent)

	testing.expect(t, parent.result.position.x == 0)
	testing.expect(t, parent.result.position.y == 0)

	testing.expect(t, child1.result.position.x == 40)
	testing.expect(t, child1.result.position.y == 10)

	testing.expect(t, child2.result.position.x == 40)
	testing.expect(t, child2.result.position.y == 120)

	testing.expect(t, child3.result.position.x == 80)
	testing.expect(t, child3.result.position.y == 130)

	testing.expect(t, child4.result.position.x == 200)
	testing.expect(t, child4.result.position.y == 130)
}
