package main

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

main :: proc() {
	// You can use print statements as follows for debugging, they'll be visible when running tests.
	fmt.eprintln("Logs from your program will appear here!")

	// Uncomment this block to pass the first stage
	listen_sock, listen_err := net.listen_tcp(net.Endpoint{
        address = net.IP4_Loopback, 
        port = 6379,
    })
    if listen_err != nil {
        fmt.panicf("%s", listen_err)
    }
    
    client_sock, client_endpoint, client_err := net.accept_tcp(listen_sock)
    if client_err != nil {
        fmt.panicf("%s", client_err)
    }
    s := stream_from_tcp_socket(client_sock)
    defer io.close(s)

    handle(s)
}

handle :: proc(w: io.Writer) {

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
        n_int, recv_err := net.recv_tcp(sock, p)
        return i64(n_int), tcp_recv_to_io_error(recv_err)
    case .Write:
        n_int, send_err := net.send_tcp(sock, p)
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
