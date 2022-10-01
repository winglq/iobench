package gorpcbench

import (
	"bytes"
	"io"
	"os"

	"github.com/valyala/gorpc"
)

func ListenAndServe(addr string) error {
	// Start rpc server serving registered service.
	s := &gorpc.Server{
		// Accept clients on this TCP address.
		Addr: addr,

		// Echo handler - just return back the message we received from the client
		Handler: func(clientAddr string, request gorpc.Request) gorpc.Response {
			if r, ok := request.Body.(io.ReadCloser); ok {
				r.Close()
			}
			file, err := os.OpenFile("../data/data", os.O_RDONLY, 0)
			if err != nil {
				buf := bytes.NewBufferString(err.Error())
				return gorpc.Response{
					Size: uint64(buf.Len()),
					Body: buf,
				}
			}
			stat, err := file.Stat()
			if err != nil {
				buf := bytes.NewBufferString(err.Error())
				return gorpc.Response{
					Size: uint64(buf.Len()),
					Body: buf,
				}
			}
			return gorpc.Response{
				Size: uint64(stat.Size()),
				Body: file,
			}
		},
	}
	return s.Serve()
}
