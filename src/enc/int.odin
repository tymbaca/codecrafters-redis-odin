package enc

import "core:strings"
import "core:bytes"
import "core:log"
import "core:testing"
import "core:strconv"
import "core:unicode"
import "core:io"

read_int :: proc(r: io.Reader) -> (v: int, err: Error) {
    digits := make([dynamic]byte, context.temp_allocator)
    defer free_all(context.temp_allocator)

    first_char := true
    sign := 1
    for {
        b := io.read_byte(r) or_return

        // check the sign if it's present
        if first_char {
            first_char = false
            
            switch b {
            case '+':
                continue
            case '-':
                sign = -1
                continue
            }
        }

        if !unicode.is_digit(rune(b)) {
            second_b := io.read_byte(r) or_return

            if b == '\r' && second_b == '\n' {
                break
            } else {
                return 0, .Invalid_Integer
            }
        }

        append(&digits, b)
    }

    if len(digits) == 0 {
        return 0, .Invalid_Integer
    }

    val, val_ok := strconv.parse_int(string(digits[:]))
    if !val_ok {
        return 0, .Invalid_Integer
    }

    return val * sign, nil
}

write_int :: proc(w: io.Writer, v: int) -> (err: Error) {
    buf: [256]byte
    str := strconv.write_int(buf[:], auto_cast v, 10)

    _ = io.write_string(w, str) or_return
    _ = io.write_string(w, "\r\n") or_return
    return nil
}

@(test)
int_test :: proc(t: ^testing.T) {
    defer free_all()

    Testcase :: struct {
        input: string,
        res: int,
        err: bool,
    }

    testcases := []Testcase{
        { input = "5\r\n",  res = 5,  err = false },
        { input = "0\r\n",  res = 0,  err = false },
        { input = "4\r\n",  res = 4,  err = false },
        { input = "+4\r\n", res = 4,  err = false },
        { input = "-4\r\n", res = -4, err = false },
        { input = "5\r",    res = 0,  err = true },
        { input = "5",      res = 0,  err = true },
        { input = "",       res = 0,  err = true },
    }

    for tt, i in testcases {
        free_all(context.allocator)
        log.info("running testcase:", i+1)

        r := string_to_stream(tt.input, context.allocator)
        res_from_read, err := read_int(r)
        if tt.err {
            testing.expect(t, err != nil)
            continue
        }

        testing.expect_value(t, err, nil)
        testing.expect_value(t, res_from_read, tt.res)

        w: bytes.Buffer
        bytes.buffer_init_allocator(&w, 0, 1024, context.allocator)

        write_int(bytes.buffer_to_stream(&w), res_from_read)
        testing.expect_value(t, bytes.buffer_to_string(&w), strings.trim_left(tt.input, "+"))
    }
}
