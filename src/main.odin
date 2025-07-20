package main

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
import nbio "src:nbio/poly"
import nbio_core "src:nbio"

main :: proc() {
    context.logger = log.create_console_logger(opt = log.Options{.Level, .Time})

	// You can use print statements as follows for debugging, they'll be visible when running tests.
    log.info("Logs from your program will appear here!")

    run()
}

Server :: struct {
    io: ^nbio.IO,
    listen_sock: net.TCP_Socket,
}


run :: proc() {
    io: nbio.IO
    nbio.init(&io, context.allocator)   

    listen_sock, listen_err := nbio.open_and_listen_tcp(&io, net.Endpoint{
        address = net.IP4_Loopback, 
        port = 6379,
    })
    if listen_err != nil {
        log.panic(listen_err)
    }

    server := Server{io = &io, listen_sock = listen_sock}

    nbio.accept(&io, listen_sock, &server, on_accept)


    for {
        client_sock, client_endpoint, client_err := net.accept_tcp(listen_sock)
        if client_err != nil {
            fmt.panicf("%s", client_err)
        }

        log.info("got connection from", client_endpoint)
        s := stream_from_tcp_socket(client_sock)

        handle_err := handle(s)
        if handle_err != nil {
            log.panic(handle_err)
        }
    }

    log.info("exiting")
}

on_accept :: proc(server: ^Server, client: net.TCP_Socket, source: net.Endpoint, err: net.Network_Error) {
    io := server.io
    if err != nil {
        #partial switch e in err {
        case net.Accept_Error:
            #partial switch e {
            case .Insufficient_Resources:
                log.warnf("insufficient resources to accept new connection, will retry in a second")
                nbio.timeout(io, time.Second, server, proc(server: ^Server) {
                    nbio.accept(server.io, server.listen_sock, server, on_accept)
                })
                return
            case:   
                log.errorf("accept error (source: %v): %v", source, e)
                return
            }
        case:
            log.panicf("non-accept error when accepting (source: %v): %v", source, err)
        }
    }

    // queue accept next connection
    nbio.accept(io, server.listen_sock, server, on_accept)

    nbio_core.test_client_and_server_send_recv()
}

handle :: proc(s: io.Stream, allocator := context.allocator) -> (err: Error) {
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
