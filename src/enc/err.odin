package enc

import "core:io"

Error :: union {
    io.Error,
    Encoding_Error,
    Unsupported_First_Byte,
}

Encoding_Error :: enum {
    None = 0,
    Invalid_Integer,
    Invalid_Bulk_String,
    Invalid_Array,
}

Unsupported_First_Byte :: struct {
    first_byte: byte,
}
