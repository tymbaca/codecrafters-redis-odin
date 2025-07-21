package enc

import "core:io"

write_simple_string :: proc(w: io.Writer, str: string, include_fb := false) -> (err: Error) {
    if include_fb {
        io.write_byte(w, '+') or_return
    }

    _ = io.write_string(w, str) or_return
    _ = io.write_string(w, "\r\n") or_return
    return nil
}
