package storage

import "core:mem"

Storage :: struct {
    // TODO: mutex
    data: map[string]string,
    allocator: mem.Allocator,
}

init :: proc(s: ^Storage, allocator := context.allocator) {
    data := make(map[string]string, allocator)
    s.data = data
    s.allocator = allocator
}

set :: proc(s: ^Storage, key, value: string) {
    s.data[key] = value
}

get :: proc(s: ^Storage, key: string) -> (val: string, ok: bool) {
    return s.data[key]
}
