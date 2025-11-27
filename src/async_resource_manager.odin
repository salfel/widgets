package main

import "base:runtime"
import "core:bytes"
import "core:fmt"
import "core:hash"
import "core:image"
import "core:image/jpeg"
import "core:image/png"
import "core:sync"
import "core:sys/linux"
import "core:testing"
import "core:thread"
import gl "vendor:OpenGL"

Async_Resource_Manager :: struct {
	assets: map[u64]^Asset,

	// threading
	pool:   thread.Pool,
	mutex:  sync.Mutex,
	fd:     linux.Fd,
}

Asset :: struct {
	mutex:   sync.Mutex,
	status:  Asset_Status,
	size:    [2]f32,
	texture: u32,
	hash:    u64,
	data:    union {
		Image_Data,
		Text_Data,
	},
}

Asset_Status :: enum {
	Pending,
	Pending_Texture,
	Finished,
}

Asset_Type :: enum {
	Image,
	Text,
}

Image_Data :: struct {
	path:  string,
	image: ^image.Image,
}

Text_Data :: struct {
	font:      string,
	text:      string,
	font_size: f32,
}

Thread_Data :: struct {
	async_resource_manager: ^Async_Resource_Manager,
	asset:                  ^Asset,
}

async_resource_manager_init :: proc(async_resource_manager: ^Async_Resource_Manager, allocator := context.allocator) {
	async_resource_manager.assets = make(map[u64]^Asset, 0, allocator)
	thread.pool_init(&async_resource_manager.pool, context.allocator, 4)
	thread.pool_start(&async_resource_manager.pool)
}

async_resource_manager_destroy :: proc(async_resource_manager: ^Async_Resource_Manager) {
	thread.pool_finish(&async_resource_manager.pool)
	thread.pool_join(&async_resource_manager.pool)

	sync.guard(&async_resource_manager.mutex)
	for key, asset in async_resource_manager.assets {
		delete_key(&async_resource_manager.assets, key)
		asset_destroy(asset)
	}

	delete(async_resource_manager.assets)
	thread.pool_destroy(&async_resource_manager.pool)

	if async_resource_manager.fd != -1 {
		linux.close(async_resource_manager.fd)
	}
}

async_resource_manager_generate_textures :: proc(async_resource_manager: ^Async_Resource_Manager) {
	for _, asset in async_resource_manager.assets {
		sync.guard(&asset.mutex)
		if asset.status != .Pending_Texture {
			continue
		}

		switch data in asset.data {
		case Image_Data:
			generate_texture_image(asset)
		case Text_Data:
			generate_texture_text(asset)
		}

		asset.status = .Finished
	}
}

request_image :: proc(async_resource_manager: ^Async_Resource_Manager, image_data: Image_Data) -> (asset: ^Asset) {
	hash := image_hash(image_data)

	if asset, ok := async_resource_manager.assets[hash]; ok && image_data == asset.data {
		return asset
	}

	asset = new(Asset)
	asset.status = .Pending
	asset.data = image_data
	asset.hash = hash

	thread_data := new(Thread_Data)
	thread_data.async_resource_manager = async_resource_manager
	thread_data.asset = asset

	thread_data.async_resource_manager.assets[thread_data.asset.hash] = thread_data.asset

	thread.pool_add_task(&async_resource_manager.pool, context.allocator, process_image, thread_data, int(asset.hash))

	return
}

process_image :: proc(task: thread.Task) {
	thread_data := cast(^Thread_Data)task.data
	defer free(thread_data)

	image_data, ok := &thread_data.asset.data.(Image_Data)
	assert(ok, "Expected Asset_Data to be of type Image_Data")

	img, err := image.load_from_file(image_data.path)
	if err != nil {
		fmt.println("couldn't load image from file", err, ", path:", image_data.path)
		return
	}

	sync.guard(&thread_data.asset.mutex)
	image_data.image = img

	thread_data.asset.size.x = f32(img.width)
	thread_data.asset.size.y = f32(img.height)
	thread_data.asset.status = .Pending_Texture

	sync.guard(&thread_data.async_resource_manager.mutex)
	linux.write(thread_data.async_resource_manager.fd, []byte{0})
}

generate_texture_image :: proc(asset: ^Asset) {
	image_data, ok := (&asset.data.(Image_Data))
	assert(ok, "Expected data to be of type Image_Data")

	bitmap := bytes.buffer_to_bytes(&image_data.image.pixels)

	format: i32 = gl.RGB

	#partial switch image_data.image.which {
	case .PNG:
		metadata := image_data.image.metadata.(^image.PNG_Info)
		format = gl.RGBA if .Alpha in metadata.header.color_type else gl.RGB
	}

	gl.GenTextures(1, &asset.texture)
	gl.BindTexture(gl.TEXTURE_2D, asset.texture)
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		format,
		i32(asset.size.x),
		i32(asset.size.y),
		0,
		u32(format),
		gl.UNSIGNED_BYTE,
		raw_data(bitmap),
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
}

generate_texture_text :: proc(asset: ^Asset) {}

asset_ready :: proc(asset: ^Asset) -> bool {
	sync.guard(&asset.mutex)
	return asset.status == .Finished
}

asset_destroy :: proc(asset: ^Asset) {
	if asset == nil {
		return
	}

	sync.lock(&asset.mutex)
	switch data in asset.data {
	case Image_Data:
		image.destroy(data.image)
	case Text_Data:
	}

	free(asset)
}

image_hash :: proc(data: Image_Data) -> u64 {
	return hash.murmur64a(transmute([]byte)data.path)
}

@(test)
test_async_resource_manager :: proc(t: ^testing.T) {
	async_resource_manager: Async_Resource_Manager
	async_resource_manager_init(&async_resource_manager, context.allocator)
	defer async_resource_manager_destroy(&async_resource_manager)

	image_data := Image_Data {
		path = "tux.png",
	}

	asset := request_image(&async_resource_manager, image_data)

	thread.pool_finish(&async_resource_manager.pool)

	testing.expect(t, asset_ready(asset))
	image_data = asset.data.(Image_Data)
}
