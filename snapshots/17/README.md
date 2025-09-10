# PlantClassifier

**Bachelor’s graduation thesis**  
Novosibirsk State University, FIT, 2026

A distributed GPU-accelerated plant image classification system built on Elixir/OTP.

## Key Results

| Metric | Our system | NVIDIA Triton (config_12) |
|--------|------------|---------------------------|
| Throughput | **33 inf/s** | 42.6 inf/s |
| p99 Latency | **1.3 s** | 3.3 s |
| GPU Memory | **1096 MB** (O(1) scaling) | 2347 MB (O(n) scaling) |
| Scalability | Add GPU workers without reconfiguration | Requires model duplication |

## Stack

- Elixir / Phoenix / Oban
- Nx / EXLA (CUDA)
- Bumblebee (ViT)
- PostgreSQL

## Quick Start

1. Install Elixir, PostgreSQL, and CUDA drivers.
2. Clone the repository.
3. `mix deps.get`
4. Configure `config/dev.exs` (database connection).
5. `mix ecto.setup`
6. Start the web node: `OBAN_QUEUES="save,20" iex -S mix phx.server`
7. Start the GPU worker: `OBAN_QUEUES="gpu,50" EXLA_CLIENT=cuda iex -S mix phx.server`

## Testing

```bash
# Synthetic Triton-style benchmark
EXLA_CLIENT=cuda mix run bench/full_nx_serving_bench.exs

# HTTP load test
python bench/load_test_api.py
```

## Documentation
Full architecture description, benchmarks, and deployment guide are available on the GitHub Wiki.

## License
MIT