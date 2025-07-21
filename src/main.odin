package main

import "core:sync"
import "core:sort"
import "core:container/intrusive/list"
import "base:runtime"
import "core:mem/virtual"
import "core:mem"
import "core:thread"
import "core:time"
import "core:log"
import "core:testing"
import "core:strconv"
import "core:unicode"
import "core:bufio"
import "core:io"
import "core:os"
import "core:bytes"
import "core:fmt"
import "core:net"
import "core:strings"
import "src:enc"

main :: proc() {
    context.logger = log.create_console_logger(opt = log.Options{.Level, .Time})

	// You can use print statements as follows for debugging, they'll be visible when running tests.
    log.info("Logs from your program will appear here!")

    run()
}

run :: proc() {
    listen_sock, listen_err := net.listen_tcp(net.Endpoint{
        address = net.IP4_Loopback, 
        port = 6379,
    })
    if listen_err != nil {
        log.panic(listen_err)
    }

    mutex_allocator: mem.Mutex_Allocator
    mem.mutex_allocator_init(&mutex_allocator, context.allocator)
    thread_allocator := mem.mutex_allocator(&mutex_allocator)

    client_thread_pool: thread.Pool
    thread.pool_init(&client_thread_pool, thread_allocator, 1024)

    conn_index := 0
    for {
        client_sock, client_endpoint, client_err := net.accept_tcp(listen_sock)
        if client_err != nil {
            fmt.panicf("%s", client_err)
        }
        conn_index += 1

        log.info("got connection from", client_endpoint)
        s := stream_from_tcp_socket(client_sock)

        client := new(Client, thread_allocator)
        client.sock = client_sock
        client.endpoint = client_endpoint
        client.stream = s

        thread.pool_add_task(&client_thread_pool, thread_allocator, handle_task, client, user_index = conn_index)
    }

    log.info("exiting")
}

Client :: struct {
    sock: net.TCP_Socket,
    endpoint: net.Endpoint,
    stream: io.Stream, // wraps sock
}

handle_task :: proc(task: thread.Task) { // TODO: user arena?
    arena: virtual.Arena
    if err := virtual.arena_init_growing(&arena); err != nil {
        log.panicf("can't create arena allocator for new connection: %v", err)
    }
    task_allocator := virtual.arena_allocator(&arena) 

    client := (^Client)(task.data)
    handle(client, context.allocator)
}

handle :: proc(client: ^Client, allocator := context.allocator) -> (err: Error) {
    s := client.stream

    defer {
        if c, ok := io.to_closer(s); ok {
            io.close(c)
        }
        free_all()
    }

    for cmd, err in read_request_iter(s, allocator) {
        if err != nil {
            return err
        }

        log.info("got command", cmd)
        
        if cmd == "PING" {
            _ = io.write_string(s, "+PONG\r\n") or_return
        }
    }

    return nil
}

read_request_iter :: proc(r: io.Reader, allocator := context.allocator) -> (cmd: string, err: Error, next: bool) {
    cmd, err = read_request(r, allocator)
    if err == .EOF {
        return "", err, false
    }
    if err != nil {
        return "", err, true
    }

    return cmd, nil, true
}

read_request :: proc(r: io.Reader, allocator := context.allocator) -> (cmd: string, err: Error) {
    fb := io.read_byte(r) or_return
    if type, ok := enc.get_type(fb); !ok || type != .Array {
        return "", enc.Error(enc.Unexpected_First_Byte{first_byte = fb})
    }

    strs := enc.read_array_of_bulk_strings(r, allocator) or_return

    assert(len(strs) > 0)

    return strs[0], nil
}

Error :: union {
    enc.Error,
}

stream_from_tcp_socket :: proc(s: net.TCP_Socket) -> io.Stream {
    return io.Stream{
        data = rawptr(uintptr(s)), // as a value
        procedure = tcp_socket_stream_proc,
    }
}

tcp_socket_stream_proc :: proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
    sock := net.TCP_Socket(uintptr(stream_data))
    
    switch mode {
    case .Read:
        if len(p) == 0 {
            return 0, nil
        }

        n_int, recv_err := net.recv_tcp(sock, p)
        if n_int == 0 && recv_err == nil {
            return 0, .EOF
        }

        return i64(n_int), tcp_recv_to_io_error(recv_err)

    case .Write:
        if len(p) == 0 {
            return 0, nil
        }

        n_int, send_err := net.send_tcp(sock, p)
        if n_int == 0 && send_err == nil {
            return 0, .EOF
        }

        return i64(n_int), tcp_send_to_io_error(send_err)

    case .Close:
        net.close(sock)
        return 0, .None

    case .Query:
		return io.query_utility({.Read, .Write, .Close, .Query})

    case .Flush, .Read_At, .Write_At, .Destroy, .Size, .Seek:
        // no need to implement
    }

    return 0, .Empty
}

tcp_recv_to_io_error :: proc(e: net.TCP_Recv_Error) -> io.Error {
    #partial switch e {
    case .None:
        return .None
    case .Connection_Closed:
        return .EOF
    case .Network_Unreachable:
        return .Unexpected_EOF
    case .Timeout:
        return .Unexpected_EOF
    }

    return .Unknown
}

tcp_send_to_io_error :: proc(e: net.TCP_Send_Error) -> io.Error {
    #partial switch e {
    case .None:
        return .None
    case .Connection_Closed:
        return .EOF
    case .Network_Unreachable:
        return .Unexpected_EOF
    case .Timeout:
        return .Unexpected_EOF
    case .Host_Unreachable:
        return .Unexpected_EOF
    case .Invalid_Argument:
        return .Invalid_Write
    }

    return .Unknown
}
