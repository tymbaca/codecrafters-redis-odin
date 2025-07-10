package enc

import "core:log"
import "core:io"

read_array_of_bulk_strings :: proc(r: io.Reader, allocator := context.allocator) -> (res: []string, err: Error) {
}

_type_to_typeid :: proc($type: Type) -> typeid {
    #partial switch type {
    case .Bulk_String:
        return string
    case .Integer:
        return int
    }

    log.panic("unsupported _type_to_typeid argument:", type)
}

read_array_of_type :: proc(r: io.Reader, $type: Type, $T: typeid, allocator := context.allocator) -> (res: []T, err: Error) {
    if _type_to_typeid(type) != T {
        log.panic("type mismatch", type, T)
    }

    length := read_int(r) or_return
    if length < 0 {
        return nil, .Invalid_Array
    }
    if length == 0 {
        return nil, nil
    }

    for _ in 0..<length {
        first_byte := io.read_byte(r) or_return
        type, ok := get_type(first_byte)
        if !ok {
            return nil, Unsupported_First_Byte{first_byte = first_byte}
        }
        
        switch type {
        case .Integer:

            read_int(r)
        }
    }
}
