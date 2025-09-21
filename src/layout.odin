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

Layout :: struct {
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

layout_measure :: proc(layout: ^Layout) {
	layout.result.size.x = layout.width if layout.width != UNDEFINED else 0
	layout.result.size.y = layout.height if layout.height != UNDEFINED else 0

	for &child in layout.children {
		layout_measure(child)

		if layout.width == UNDEFINED {
			layout.result.size.x += child.result.size.x + child.margin.left + child.margin.right
		}

		if layout.height == UNDEFINED && child.result.size.y > layout.result.size.y {
			layout.result.size.y =
				child.height + child.margin.top + child.margin.bottom + layout.border.top + layout.border.bottom
		}
	}

	if layout.width == UNDEFINED {
		layout.result.size.x += layout.padding.left + layout.padding.right
	}
	layout.result.size.x += layout.border.left + layout.border.right

	if layout.height == UNDEFINED {
		layout.result.size.y += layout.padding.top + layout.padding.bottom
	}
	layout.result.size.y += layout.border.top + layout.border.bottom
}

layout_arrange :: proc(layout: ^Layout, offset: f32 = 0) {
	offset := offset + layout.margin.left
	layout.result.position.x = offset
	offset += layout.padding.left + layout.border.left

	for &child in layout.children {
		child.result.position.y = layout.result.position.y + layout.padding.top + layout.border.top + child.margin.top
		layout_arrange(child, offset)
		offset += child.result.size.x + child.margin.right
	}
}

@(test)
test_layout_measure :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)
	child1 := layout_make()
	child2 := layout_make()

	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.width = UNDEFINED
	parent.padding.left = 10

	child1.width = 100
	child1.height = 100
	child1.margin.left = 10
	child1.margin.right = 10

	child2.width = 200
	child2.height = 200
	child2.border.left = 10

	layout_measure(&parent)

	testing.expect(t, parent.result.size.x == 340)
	testing.expect(t, child1.result.size.y == 100)
	testing.expect(t, child2.result.size.x == 210)
}

@(test)
test_layout_arrange :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)
	child1 := layout_make()
	child2 := layout_make()

	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.width = UNDEFINED
	parent.margin.left = 20
	parent.padding.left = 10
	parent.border.left = 10
	parent.border.right = 10

	child1.width = 100
	child1.height = 100
	child1.margin.left = 10
	child1.margin.right = 10
	child1.border.left = 10
	child1.border.right = 10

	child2.width = 200
	child2.height = 200
	child2.margin.left = 10
	child2.border.left = 10

	layout_measure(&parent)
	layout_arrange(&parent)

	testing.expect(t, parent.result.position.x == 20)
	testing.expect(t, parent.result.size.x == 390)
	testing.expect(t, child1.result.position.x == 50)
	testing.expect(t, child1.result.size.x == 120)
	testing.expect(t, child2.result.position.x == 180)
	testing.expect(t, child2.result.size.x == 210)
}
