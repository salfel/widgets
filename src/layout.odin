package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:testing"

UNDEFINED :: -1

Layout_Type :: enum {
	Block,
	Box,
}

Layout :: struct {
	type:     Layout_Type,
	style:    Layout_Style,
	children: [dynamic]^Layout,

	// result
	result:   struct {
		size:     [2]f32,
		position: [2]f32,
	},
}

layout_make :: proc(allocator := context.allocator) -> Layout {
	layout := Layout {
		type = .Block,
		style = DEFAULT_LAYOUT_STYLE,
		result = {size = {0, 0}, position = {0, 0}},
		children = make([dynamic]^Layout, allocator),
	}

	return layout
}

layout_destroy :: proc(layout: ^Layout) {
	delete(layout.children)
}

layout_compute :: proc(layout: ^Layout, available: f32 = 0) {
	if layout.type == .Box {
		children_size := [2]f32{0, 0}
		for &child in layout.children {
			layout_compute(child)

			children_size.x += child.result.size.x + child.style.margin.left + child.style.margin.right
			children_size.y = math.max(
				children_size.y,
				child.result.size.y + child.style.margin.top + child.style.margin.bottom,
			)
		}

		if layout.style.width == UNDEFINED {
			layout.result.size.x =
				children_size.x +
				layout.style.padding.left +
				layout.style.padding.right +
				layout.style.border.width +
				layout.style.border.width
		} else do layout.result.size.x = layout.style.width + layout.style.border.width + layout.style.border.width

		if layout.style.height == UNDEFINED {
			layout.result.size.y =
				children_size.y +
				layout.style.padding.top +
				layout.style.padding.bottom +
				layout.style.border.width +
				layout.style.border.width
		} else do layout.result.size.y = layout.style.height + layout.style.border.width + layout.style.border.width

		return
	}

	layout.result.size.x = available - layout.style.margin.left - layout.style.margin.right
	layout.result.size.y = layout.style.height + layout.style.border.width + layout.style.border.width

	children_height :=
		layout.style.border.width + layout.style.border.width + layout.style.padding.top + layout.style.padding.bottom

	box_height: f32 = 0
	for &child in layout.children {
		layout_compute(
			child,
			layout.result.size.x -
			layout.style.padding.left -
			layout.style.padding.right -
			layout.style.border.width -
			layout.style.border.width,
		)

		child_height := child.result.size.y + child.style.margin.top + child.style.margin.bottom

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
	parent_offset := [2]f32{offset.x + layout.style.margin.left, offset.y + layout.style.margin.top}
	layout.result.position = parent_offset
	parent_offset.x += layout.style.padding.left + layout.style.border.width
	parent_offset.y += layout.style.padding.top + layout.style.border.width

	offset := parent_offset

	prev_child: ^Layout = nil
	for &child in layout.children {
		if prev_child != nil && prev_child.type == .Box && child.type == .Block {
			offset.y += prev_child.result.size.y + prev_child.style.margin.bottom
			offset.x = parent_offset.x
		}

		layout_arrange(child, offset)

		if child.type == .Box {
			offset.x += child.result.size.x + child.style.margin.left + child.style.margin.right
		} else {
			offset.y += child.result.size.y + child.style.margin.bottom + child.style.margin.top
			offset.x = parent_offset.x
		}

		prev_child = child
	}
}

@(test)
test_layout_compute_block :: proc(t: ^testing.T) {
	parent := layout_make({})
	defer layout_destroy(&parent)
	child1 := layout_make({})
	child2 := layout_make({})

	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.type = .Block
	parent.style.height = 100
	parent.style.padding.left = 30
	parent.style.margin.right = 100
	parent.style.padding.top = 10

	child1.type = .Block
	child1.style.height = 100
	child1.style.margin.left = 10
	child1.style.margin.right = 10

	child2.type = .Block
	child2.style.height = 200
	child2.style.border.width = 10

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
	parent := layout_make({})
	defer layout_destroy(&parent)
	child1 := layout_make({})
	child2 := layout_make({})

	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.type = .Box
	parent.style.padding.left = 30
	parent.style.margin.right = 100
	parent.style.padding.top = 10

	child1.type = .Box
	child1.style.width = 100
	child1.style.height = 100
	child1.style.margin.left = 10
	child1.style.margin.right = 10

	child2.type = .Box
	child2.style.width = 200
	child2.style.height = 200
	child2.style.border.width = 10

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
	parent := layout_make({})
	defer layout_destroy(&parent)
	child1 := layout_make({})
	child2 := layout_make({})
	defer layout_destroy(&child2)

	child3 := layout_make({})
	child4 := layout_make({})

	append(&child2.children, &child3)
	append(&child2.children, &child4)
	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.type = .Block
	parent.style.height = 100
	parent.style.padding.left = 30
	parent.style.margin.right = 100
	parent.style.padding.top = 10

	child1.type = .Block
	child1.style.height = 100
	child1.style.margin.left = 10
	child1.style.margin.right = 10
	child1.style.border.width = 10
	child1.style.border.width = 10

	child2.type = .Block
	child2.style.margin.left = 10
	child2.style.border.width = 10
	child2.style.padding.left = 30
	child2.style.border.width = 10

	child3.type = .Box
	child3.style.width = 100
	child3.style.height = 100
	child3.style.border.width = 10

	child4.type = .Box
	child4.style.width = 100
	child4.style.height = 150
	child4.style.margin.left = 10

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
