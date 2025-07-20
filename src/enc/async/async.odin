package async

import "core:net"
import nbio "src:nbio/poly"

Context :: struct {
    io: ^nbio.IO,
    scanner: ^Scanner,
}

parse_bulk_string :: proc(ctx: ^Context, callback: proc(ctx: ^Context, result: string, err: Error)) {
    parse_int(io, on_length)

    on_length :: proc(ctx: ^Context, length: int, err: Error) {
        body := make([]byte, length+2)
        if !read_all_or_queue(ctx.scanner, body, on_length, hint = length) {
            return
        }

        callback(ctx, string(body), nil)
    }
}

parse_int :: proc(ctx: ^Context, callback: proc(ctx: ^Context, result: int, err: Error)) {
    digit, err := read_byte(buffer)
    if err == .Need_More {
        fill(io, buffer, proc() {
            parse_int(io)
        })
    }
}
