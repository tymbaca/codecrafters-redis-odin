package enc

Type :: enum {
    Array,
    Bulk_String,
    Integer,
}

get_type :: proc(ch: byte) -> (Type, bool) {
    switch ch {
    case ':':
        return .Integer, true
    case '$':
        return .Bulk_String, true
    case '*':
        return .Array, true
    }

    return nil, false
}
