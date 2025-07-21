package enc

import "core:io"
write_null :: proc(w: io.Writer) -> (err: Error) {
    _ = io.write_string(w, "_\r\n") or_return
    return nil
}
