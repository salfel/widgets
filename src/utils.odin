package main

Bounds :: struct(T: typeid) {
	position: [2]T,
	size:     [2]T,
}

convert_vec :: proc(vec: [$N]$T, $R: typeid) -> [N]R {
	ret := [N]R{}
	for i in 0 ..< N {
		ret[i] = R(vec[i])
	}
	return ret
}
