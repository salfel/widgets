package main

convert_vec :: proc(vec: [$N]$T, $R: typeid) -> [N]R {
	ret := [N]R{}
	for i in 0 ..< N {
		ret[i] = R(vec[i])
	}
	return ret
}
