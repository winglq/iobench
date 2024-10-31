package iorpcbench

import (
	"encoding/binary"
	"errors"
	"io"
	"os"
	"time"

	"github.com/hexilee/iorpc"
)

var (
	Dispatcher        = iorpc.NewDispatcher()
	ServiceNoop       iorpc.Service
	ServiceReadData   iorpc.Service
	ServiceReadMemory iorpc.Service
)

type StaticBuffer []byte
type ReadHeaders struct {
	Offset, Size uint64
	encodeBuf    [16]byte
}

func (h *ReadHeaders) Encode(w io.Writer) (int, error) {
	binary.BigEndian.PutUint64(h.encodeBuf[0:8], h.Offset)
	binary.BigEndian.PutUint64(h.encodeBuf[8:16], h.Size)
	return w.Write(h.encodeBuf[:])
}

func (h *ReadHeaders) Decode(b []byte) error {
	if len(b) != 16 {
		panic("")
	}
	h.Offset = binary.BigEndian.Uint64(b[0:8])
	h.Size = binary.BigEndian.Uint64(b[8:16])
	return nil
}

var (
	dataFile *os.File
	fileSize int64

	staticData = make(StaticBuffer, 128*1024)
)

func init() {
	iorpc.RegisterHeaders(func() iorpc.Headers {
		return new(ReadHeaders)
	})

	ServiceNoop, _ = Dispatcher.AddService("Noop", func(clientAddr string, request iorpc.Request) (response *iorpc.Response, err error) {
		return &iorpc.Response{}, nil
	})
	ServiceReadData, _ = Dispatcher.AddService(
		"ReadData",
		func(clientAddr string, request iorpc.Request) (*iorpc.Response, error) {
			request.Body.Close()
			size := uint64(128 * 1024)
			offset := uint64(1)

			if request.Headers != nil {
				if headers := request.Headers.(*ReadHeaders); headers != nil {
					size = headers.Size
					offset = headers.Offset
				}
			}

			if offset >= uint64(fileSize) {
				return nil, errors.New("bad request, offset out of range")
			}

			if offset+size > uint64(fileSize) {
				size = uint64(fileSize) - offset
			}

			// make sure we don't touch EOF
			_, err := dataFile.Seek(0, io.SeekStart)
			if err != nil {
				panic(err)
			}
			return &iorpc.Response{
				Body: iorpc.Body{
					Offset:   offset,
					Size:     size,
					Reader:   &File{file: dataFile},
					NotClose: true,
				},
			}, nil
		},
	)

	ServiceReadMemory, _ = Dispatcher.AddService(
		"ReadMemory",
		func(clientAddr string, request iorpc.Request) (*iorpc.Response, error) {
			request.Body.Close()
			return &iorpc.Response{
				Body: iorpc.Body{
					Size:   uint64(len(staticData)),
					Reader: staticData,
				},
			}, nil
		},
	)
}

type File struct {
	file *os.File
}

func (f *File) Close() error {
	return f.file.Close()
}

func (f *File) File() uintptr {
	return f.file.Fd()
}

func (f *File) Read(p []byte) (n int, err error) {
	return f.file.Read(p)
}

func ListenAndServe(addr string) error {
	file, err := os.OpenFile("../data/tmp/bigdata", os.O_RDONLY, 0)
	if err != nil {
		return err
	}
	stat, err := file.Stat()
	if err != nil {
		return err
	}
	dataFile, fileSize = file, stat.Size()

	// Start rpc server serving registered service.
	s := &iorpc.Server{
		// Accept clients on this TCP address.
		Addr:       addr,
		FlushDelay: time.Microsecond * 10,

		// Echo handler - just return back the message we received from the client
		Handler: Dispatcher.HandlerFunc(),
	}
	s.CloseBody = true
	return s.Serve()
}

func (b StaticBuffer) Buffer() [][]byte {
	return [][]byte{b}
}

func (b StaticBuffer) Close() error {
	return nil
}

func (b StaticBuffer) Read(p []byte) (n int, err error) {
	n = copy(p, b)
	return
}
