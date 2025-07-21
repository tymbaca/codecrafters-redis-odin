package enc

import "core:log"
import "core:testing"
import "core:strconv"
import "core:io"
import "core:bytes"
import "core:strings"

read_bulk_string :: proc(r: io.Reader, allocator := context.allocator) -> (str: string, err: Error) {
    // read the length
    length := read_int(r) or_return

    // read the body
    body := make([]byte, length, allocator = allocator)
    _ = io.read_full(r, body[:]) or_return

    // read crlf
    cr := io.read_byte(r) or_return
    lf := io.read_byte(r) or_return

    if !(cr == '\r' && lf == '\n') {
        return "", .Invalid_Bulk_String
    }

    return string(body), nil
}

// TODO: handle quotes
write_bulk_string :: proc(w: io.Writer, str: string) -> (err: Error) {
    write_int(w, len(str)) or_return
    _ = io.write_string(w, str) or_return
    _ = io.write_string(w, "\r\n") or_return
    return nil
}

@(test)
bulk_string_test :: proc(t: ^testing.T) {
    defer free_all()

    Testcase :: struct {
        input: string,
        res: string,
        err: bool,
    }

    testcases := []Testcase{
        { input = "5\r\nhello\r\n", res = "hello", err = false },
        { input = "0\r\n\r\n",      res = "",      err = false },
        { input = "5\rhello\r\n",   res = "",      err = true },
        { input = "4\r\nhello\r\n", res = "",      err = true },
        { input = "5",              res = "",      err = true },
        { input = "",               res = "",      err = true },
    }

    for tt, i in testcases {
        free_all(context.allocator)
        log.info("running testcase:", i+1)

        r := string_to_stream(tt.input, context.allocator)
        res_from_read, err := read_bulk_string(r, context.allocator)
        if tt.err {
            testing.expect(t, err != nil)
            continue
        }

        testing.expect_value(t, err, nil)
        testing.expect_value(t, res_from_read, tt.res)

        w: bytes.Buffer
        bytes.buffer_init_allocator(&w, 0, 1024, context.allocator)

        write_bulk_string(bytes.buffer_to_stream(&w), res_from_read)
        testing.expect_value(t, bytes.buffer_to_string(&w), tt.input)
    }
}

string_to_stream :: #force_inline proc(str: string, allocator := context.allocator) -> io.Stream {
    b := new(bytes.Buffer, allocator = allocator)
    bytes.buffer_init_string(b, str)
    return bytes.buffer_to_stream(b)
}
