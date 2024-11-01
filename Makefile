DATA_TMP_DIR?=./data/tmp
OUTPUT_DIR?=./output
HOST?=localhost
PORT?=8000
H2C_PORT?=8002
HTTP2_PORT?=8443
IORPC_PORT?=8003
TCP_PORT?=8004
TARGET?=slow
GOMAXPROCS?=16
MOCK_BANDWIDTH?=100GiB
MOCK_LATENCY?=1ms
WORKERS?=400
TIME?=30s
SESSIONS?=64
CARGO_DEV_OPTIONS=--manifest-path=rust/Cargo.toml


bench: ensure-bench-tool
	$(OUTPUT_DIR)/bin/oha -c $(WORKERS) -z $(TIME) http://$(HOST):$(PORT)/$(TARGET) && curl http://$(HOST):$(PORT)/stat/$(TARGET)

bench-h2c:
	h2load -D $(TIME) -t 8 -c $$(( $(WORKERS) / 4 + 1 )) -m $(SESSIONS) -f 128K http://$(HOST):$(H2C_PORT)/$(TARGET) && curl http://$(HOST):$(H2C_PORT)/stat/$(TARGET)

bench-http2:
	h2load -D $(TIME) -t 8 -c $$(( $(WORKERS) / 4 + 1 )) -m $(SESSIONS) -f 128K https://$(HOST):$(HTTP2_PORT)/$(TARGET) && curl --insecure https://$(HOST):$(HTTP2_PORT)/stat/$(TARGET)

bench-tcp: 
	cd go/client/tcp && TIME=$(TIME) WORKERS=$$(( $(WORKERS) / 4 + 1 )) TCP_PORT=$(TCP_PORT) go run .

bench-iorpc:
	cd go/client/iorpc && go build -o iorpc && TIME=$(TIME) WORKERS=$$(( $(WORKERS) / 4 + 1 )) SESSIONS=$(SESSIONS) IORPC_PORT=$(IORPC_PORT) ./iorpc
bench-memory:
	cd go/client/memory && TIME=$(TIME) WORKERS=$$(( $(WORKERS) / 4 + 1 )) RANDOM=$(RANDOM) go run .

run-rust-server: ensure-bigdata 
	cargo run $(CARGO_DEV_OPTIONS) --release

run-go-server: ensure-bigdata ensure-cert
	cd go && go build -o server && GOMAXPROCS=$(GOMAXPROCS) MOCK_BANDWIDTH=$(MOCK_BANDWIDTH) MOCK_LATENCY=$(MOCK_LATENCY) ./server

clean: clean-rust
	rm -rf $(OUTPUT_DIR)
	rm -rf $(DATA_TMP_DIR)

check: check-rust build-go

test: test-rust test-go

fmt: fmt-rust fmt-go

lint: lint-rust lint-go

clean-rust:
	cargo clean $(CARGO_DEV_OPTIONS)

check-rust:
	cargo check $(CARGO_DEV_OPTIONS)

test-rust:
	cargo test $(CARGO_DEV_OPTIONS)

fmt-rust:
	cargo fmt $(CARGO_DEV_OPTIONS)

lint-rust:
	cargo clippy $(CARGO_DEV_OPTIONS)

build-go:
	cd go && go build ./...

test-go:
	cd go && go test ./...

fmt-go:
	cd go && go fmt ./...

lint-go:
	cd go && go vet ./...

ensure-output:
	mkdir -p $(OUTPUT_DIR)

ensure-data:
	mkdir -p $(DATA_TMP_DIR)

ensure-bench-tool: ensure-output
	if [ ! -f $(OUTPUT_DIR)/bin/oha ]; then cargo install oha --root $(OUTPUT_DIR) && chmod +x $(OUTPUT_DIR)/bin/oha; fi

ensure-cert: ensure-output
	if [ ! -f $(OUTPUT_DIR)/server.key ]; then openssl req -newkey rsa:2048 -nodes -keyout $(OUTPUT_DIR)/server.key -x509 -days 365 -out $(OUTPUT_DIR)/server.crt; fi

ensure-bigdata: ensure-data
	if [ ! -f $(DATA_TMP_DIR)/bigdata ]; then dd if=/dev/urandom of=$(DATA_TMP_DIR)/bigdata bs=1M count=1024; fi

