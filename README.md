# widgets

`widgets` is a GUI toolkit / rendering engine prototype written in Odin for Linux Wayland.

This is not a polished library, but rather a project for myself to learn about computer graphics and enhance my low-level systems programming skills, As I am deeply interested in those areas.

## Features

- A custom retained-mode widget system with parent/child hierarchy, widget registration, focus management, and event dispatch.
- A flexbox-like layout engine with measure, compute, and arrange phases.
- Layout constraints with min/preferred sizing, padding, margin, borders, expansion rules, and absolute positioning.
- OpenGL rendering for boxes, images, and text.
- Stencil-based clipping for nested widget rendering.
- A text rendering pipeline built on Pango/Cairo/fontconfig and uploaded to OpenGL textures.
- An editable text field widget with cursor movement, selection, insertion, deletion, copy, cut, paste, and horizontal scrolling.
- Pointer and keyboard input handling on Wayland, including modifier tracking and key repeat.
- Wayland clipboard integration through the data-control protocol.
- A style system with observable style updates for rectangles, text, and text fields.
- A timer/event loop using Linux polling and timerfds.

## Tech Stack

- Language: Odin
- Platform: Linux / Wayland
- Graphics: EGL + OpenGL 3.3
- Text: Pango + Cairo + fontconfig
- Input/keymap: xkbcommon

## Building
```bash
odin build src -collection:lib=lib --out:widgets
odin test src -collection:lib=lib
```
