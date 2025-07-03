package main

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
}
