module github.com/hexilee/iobench/go

go 1.19

require (
	github.com/dustin/go-humanize v1.0.0
	github.com/felixge/fgprof v0.9.3
	github.com/google/uuid v1.3.0
	github.com/hexilee/iorpc v0.0.0-20221030172936-ad52e44ff86e
	github.com/valyala/fasthttp v1.40.0
	golang.org/x/net v0.0.0-20221004154528-8021a29435af
	golang.org/x/sync v0.1.0
)

require (
	github.com/andybalholm/brotli v1.0.4 // indirect
	github.com/google/pprof v0.0.0-20211214055906-6f57359322fd // indirect
	github.com/klauspost/compress v1.15.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/valyala/bytebufferpool v1.0.0 // indirect
	golang.org/x/text v0.3.7 // indirect
)

replace github.com/hexilee/iorpc v0.0.0-20221030172936-ad52e44ff86e => github.com/winglq/iorpc v0.0.0-20241031081100-1cf621e6c358
