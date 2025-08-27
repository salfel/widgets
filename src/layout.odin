package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:testing"

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
	min:       f32,
	preferred: f32,
	max:       f32,
	height:    f32,
	padding:   Edges,
	margin:    Edges,
	border:    Edges,
	result:    struct {
		size:      [2]f32,
		position:  [2]f32,
		clip:      bool,

		// only used internaly for computing the layout
		min:       f32,
		preferred: f32,
		max:       f32,
	},
	children:  [dynamic]^Layout,
}

layout_make :: proc(min: f32, preferred: f32, max: f32 = math.INF_F32, allocator := context.allocator) -> Layout {
	return Layout {
		min = min,
		preferred = preferred,
		max = max,
		height = 0,
		padding = {left = 0, right = 0, top = 0, bottom = 0},
		margin = {left = 0, right = 0, top = 0, bottom = 0},
		border = {left = 0, right = 0, top = 0, bottom = 0},
		result = {size = {0, 0}, position = {0, 0}, clip = false},
		children = make([dynamic]^Layout, allocator),
	}
}

layout_destroy :: proc(layout: ^Layout) {
	delete(layout.children)
}

layout_measure :: proc(layout: ^Layout) {
	min: f32 = 0
	preferred: f32 = 0
	max: f32 = 0
	height: f32 = 0

	for &child in layout.children {
		layout_measure(child)

		min += child.result.min + child.margin.left + child.margin.right
		preferred += child.result.preferred + child.margin.left + child.margin.right

		if max != math.INF_F32 {
			if child.result.max != math.INF_F32 {
				max += child.result.max
			} else {
				max = math.INF_F32
			}
		}

		height = math.max(height, child.result.size.y + child.margin.top + child.margin.bottom)
	}

	layout.result.size.y = layout.height
	if layout.height == 0 {
		layout.result.size.y = height
	} else if height > layout.height - layout.padding.top - layout.padding.bottom {
		layout.result.clip = true
	}

	layout.result.size.y += layout.border.top + layout.border.bottom

	layout.result.min =
		math.max(min + layout.padding.left + layout.padding.right, layout.min) +
		layout.border.left +
		layout.border.right
	layout.result.preferred =
		math.max(preferred + layout.padding.left + layout.padding.right, layout.preferred) +
		layout.border.left +
		layout.border.right
	layout.result.max =
		math.max(max + layout.padding.left + layout.padding.right, layout.max) +
		layout.border.left +
		layout.border.right
}

layout_compute :: proc(layout: ^Layout, width: f32, allocator := context.allocator) {
	layout.result.size.x = width

	for &child in layout.children {
		child.result.size.x = child.result.preferred
	}

	// shrink
	if layout.result.preferred > width && len(layout.children) > 0 {
		space := layout.result.preferred - width
		children := make([dynamic]^Layout, allocator)
		append(&children, ..layout.children[:])
		defer delete(children)

		for len(children) > 0 && space > 0 {
			min_distance := math.INF_F32
			#reverse for child, i in children {
				if child.result.size.x - child.result.min <= 0 {
					assert(child.result.size.x == child.result.min, "expected child width to be equal to min")
					unordered_remove(&children, i)
					continue
				}

				distance := child.result.size.x - child.result.min
				min_distance = math.min(min_distance, distance)
			}

			min_distance = math.min(min_distance * f32(len(children)), space) / f32(len(children))

			for &child in children {
				child.result.size.x -= min_distance
				space -= min_distance
			}
		}
	}

	// grow
	if layout.result.preferred < width && len(layout.children) > 0 {
		space := width - layout.result.preferred
		children := make([dynamic]^Layout, allocator)
		append(&children, ..layout.children[:])
		defer delete(children)

		for len(children) > 0 && space > 0 {
			min_distance := math.INF_F32

			#reverse for child, i in children {
				if child.result.size.x - child.result.max >= 0 {
					assert(child.result.size.x == child.result.max)
					unordered_remove(&children, i)
					continue
				}

				distance := child.result.max - child.result.size.x
				min_distance = math.min(min_distance, distance)
			}

			min_distance = math.min(min_distance * f32(len(children)), space) / f32(len(children))

			for &child in children {
				child.result.size.x += min_distance
				space -= min_distance
			}
		}
	}

	for &child in layout.children {
		layout_compute(child, child.result.size.x)
	}

}

layout_arrange :: proc(layout: ^Layout) {
	offset: f32 = layout.result.position.x

	for &child in layout.children {
		child.result.position.x = layout.padding.left + child.margin.left + offset + layout.border.left
		child.result.position.y = layout.result.position.y + child.margin.top + layout.padding.top + layout.border.top
		offset += child.result.size.x + child.margin.left + child.margin.right

		layout_arrange(child)
	}

}

@(test)
test_layout_measure :: proc(t: ^testing.T) {
	{
		layout := layout_make(100, 200)
		defer layout_destroy(&layout)
		children := []Layout{layout_make(100, 200), layout_make(100, 200)}
		for &child in children {
			append(&layout.children, &child)
		}

		layout_measure(&layout)
		testing.expect(t, layout.result.min == 200)
		testing.expect(t, layout.result.preferred == 400)
	}

	// ----

	{
		layout := layout_make(0, 0)
		layout.padding.left = 100
		defer layout_destroy(&layout)
		children := []Layout{layout_make(100, 200), layout_make(100, 200)}
		for &child in children {
			append(&layout.children, &child)
		}

		layout_measure(&layout)
		testing.expect(t, layout.result.min == 300)
		testing.expect(t, layout.result.preferred == 500)

	}
}

@(test)
test_layout_compute_shrink :: proc(t: ^testing.T) {
	layout := layout_make(0, 0)
	defer layout_destroy(&layout)

	children := []Layout{layout_make(50, 200), layout_make(180, 200)}
	for &child in children {
		append(&layout.children, &child)
	}

	layout_measure(&layout)
	layout_compute(&layout, 300)

	testing.expect(t, layout.children[0].result.size.x == 120)
	testing.expect(t, layout.children[1].result.size.x == 180)
}

@(test)
test_layout_compute_grow :: proc(t: ^testing.T) {
	layout := layout_make(0, 0)
	defer layout_destroy(&layout)

	child1 := layout_make(100, 200, 220)
	child2 := layout_make(100, 200)
	child2.margin.left = 30
	append(&layout.children, &child1)
	append(&layout.children, &child2)

	layout_measure(&layout)
	testing.expect(t, layout.result.min == 230)
	testing.expect(t, layout.result.preferred == 430)

	layout_compute(&layout, 500)

	testing.expect(t, layout.children[0].result.size.x == 220)
	testing.expect(t, layout.children[1].result.size.x == 250)
}

@(test)
test_layout_arrange :: proc(t: ^testing.T) {
	layout := layout_make(0, 0)
	layout.padding.left = 100
	defer layout_destroy(&layout)

	child1 := layout_make(100, 200, 220)
	child2 := layout_make(100, 200)
	child2.margin.left = 150
	append(&layout.children, &child1)
	append(&layout.children, &child2)

	layout_measure(&layout)
	layout_compute(&layout, 500)
	layout_arrange(&layout)

	testing.expect(t, child1.result.position.x == 100)
	testing.expect(t, child1.result.size.x == 125)
	testing.expect(t, child2.result.position.x == 375)
	testing.expect(t, child2.result.size.x == 125)
}
