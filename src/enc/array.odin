package enc

import "core:log"
import "core:io"

read_array_of_bulk_strings :: proc(r: io.Reader, allocator := context.allocator) -> (res: []string, err: Error) {
    length := read_int(r) or_return
    if length < 0 {
        return nil, .Invalid_Array
    }
    if length == 0 {
        return nil, nil
    }

    res = make([]string, length, allocator = allocator)

    for i in 0..<length {
        first_byte := io.read_byte(r) or_return
        type, ok := get_type(first_byte)
        if !ok {
            return nil, Unsupported_First_Byte{first_byte = first_byte}
        }
        
        if type != .Bulk_String {
            return nil, .Unexpected_Array_Type
        }

        res[i] = read_bulk_string(r, allocator) or_return
    }

    return res, nil
}

write_array_of_bulk_strings :: proc(w: io.Writer, arr: []string) -> (err: Error) {
    write_int(w, len(arr)) or_return

    for item in arr {
        write_bulk_string(w, item) or_return
    }

    return nil
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
