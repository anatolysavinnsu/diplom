# full_nx_serving_bench.exs

defmodule FullNxBench do
  @model_name "nateraw/vit-base-beans"

  @batch_sizes [1, 2, 4, 8, 16, 32, 64]
  @concurrency_levels [32, 64, 128, 256, 512, 1024]

  @benchmark_seconds 10
  @batch_timeout 10

  @shape {224, 224, 3}
  @pool_size 256

  # ------------------------------------------------------------
  # INPUT POOL
  # ------------------------------------------------------------

  def input_pool do
    tensor =
      Nx.broadcast(
        Nx.tensor(127, type: :u8),
        @shape
      )

    for _ <- 1..@pool_size do
      tensor
    end
    |> :erlang.list_to_tuple()
  end

  # ------------------------------------------------------------
  # ETS
  # ------------------------------------------------------------

  def setup_ets do
    :ets.new(:metrics, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.insert(:metrics, [
      {:count, 0},
      {:errors, 0}
    ])
  end

  def cleanup_ets do
    :ets.delete(:metrics)
  end

  # ------------------------------------------------------------
  # MODEL
  # ------------------------------------------------------------

  def build_serving(batch_size) do
    {:ok, model} =
      Bumblebee.load_model({:hf, @model_name})

    {:ok, featurizer} =
      Bumblebee.load_featurizer({:hf, @model_name})

    Bumblebee.Vision.image_classification(
      model,
      featurizer,
      compile: [batch_size: batch_size],
      defn_options: [compiler: EXLA]
    )
  end

  # ------------------------------------------------------------
  # WARMUP
  # ------------------------------------------------------------

  def warmup(serving_name, batch_size) do
    IO.puts("warmup batch=#{batch_size}")

    input =
      Nx.broadcast(
        Nx.tensor(127, type: :u8),
        @shape
      )

    for _ <- 1..20 do
      Nx.Serving.batched_run(serving_name, input)
    end
  end

  # ------------------------------------------------------------
  # WORKER
  # ------------------------------------------------------------

  def worker(parent, serving_name, pool, stopper_pid) do
    case :hdr_histogram.open(60_000_000, 3) do
      {:ok, histogram} ->
        loop(parent, serving_name, pool, stopper_pid, histogram)

      _ ->
        send(parent, {:histogram, :error})
    end
  end

  defp loop(parent, serving_name, pool, stopper_pid, histogram) do
    if Process.alive?(stopper_pid) do
      input =
        elem(
          pool,
          :rand.uniform(tuple_size(pool)) - 1
        )

      start = System.monotonic_time(:microsecond)

      try do
        Nx.Serving.batched_run(serving_name, input)

        latency = System.monotonic_time(:microsecond) - start

        :hdr_histogram.record(histogram, latency)
        :ets.update_counter(:metrics, :count, 1)
      rescue
        _ ->
          :ets.update_counter(:metrics, :errors, 1)
      end

      loop(parent, serving_name, pool, stopper_pid, histogram)
    else
      send(parent, {:histogram, histogram})
    end
  end

  # ------------------------------------------------------------
  # HISTOGRAM COLLECT
  # ------------------------------------------------------------

  def collect_histograms(workers_left, merged, timeout_ms) do
    if workers_left == 0 do
      merged
    else
      receive do
        {:histogram, :error} ->
          collect_histograms(workers_left - 1, merged, timeout_ms)

        {:histogram, histogram} ->
          merged =
            case merged do
              nil ->
                {:ok, histogram}

              {:ok, current} ->
                case :hdr_histogram.add(current, histogram) do
                  {:ok, combined} -> {:ok, combined}
                  # оставляем предыдущее при ошибке
                  _ -> merged
                end
            end

          collect_histograms(workers_left - 1, merged, timeout_ms)
      after
        timeout_ms ->
          merged
      end
    end
  end

  # ------------------------------------------------------------
  # LATENCY
  # ------------------------------------------------------------

  def latency_stats({:ok, histogram}) do
    p50 = :hdr_histogram.percentile(histogram, 50.0) / 1000
    p95 = :hdr_histogram.percentile(histogram, 95.0) / 1000
    p99 = :hdr_histogram.percentile(histogram, 99.0) / 1000
    max = :hdr_histogram.max(histogram) / 1000

    %{p50: p50, p95: p95, p99: p99, max: max}
  end

  def latency_stats(_) do
    %{p50: 0, p95: 0, p99: 0, max: 0}
  end

  # ------------------------------------------------------------
  # SINGLE CASE
  # ------------------------------------------------------------

  def run_case(batch_size, concurrency) do
    IO.puts("")
    IO.puts("==================================================")
    IO.puts("batch=#{batch_size} concurrency=#{concurrency}")

    setup_ets()

    serving = build_serving(batch_size)
    serving_name = :"serving_#{batch_size}"

    {:ok, pid} =
      Nx.Serving.start_link(
        name: serving_name,
        serving: serving,
        batch_size: batch_size,
        batch_timeout: @batch_timeout
      )

    warmup(serving_name, batch_size)

    pool = input_pool()
    parent = self()

    stopper =
      spawn(fn ->
        Process.sleep(@benchmark_seconds * 1000)
      end)

    workers =
      for _ <- 1..concurrency do
        spawn(fn ->
          worker(parent, serving_name, pool, stopper)
        end)
      end

    Process.sleep(@benchmark_seconds * 1000 + 500)
    Process.exit(stopper, :kill)

    histogram = collect_histograms(concurrency, nil, 5000)

    total = :ets.lookup_element(:metrics, :count, 2)
    errors = :ets.lookup_element(:metrics, :errors, 2)
    throughput = total / @benchmark_seconds

    stats = latency_stats(histogram)

    IO.puts("throughput=#{Float.round(throughput, 2)} req/s")
    IO.puts("errors=#{errors}")
    IO.puts("p50=#{Float.round(stats.p50, 2)} ms")
    IO.puts("p95=#{Float.round(stats.p95, 2)} ms")
    IO.puts("p99=#{Float.round(stats.p99, 2)} ms")
    IO.puts("max=#{Float.round(stats.max, 2)} ms")

    Enum.each(workers, fn w -> Process.exit(w, :kill) end)
    GenServer.stop(pid)
    cleanup_ets()

    %{
      batch: batch_size,
      concurrency: concurrency,
      throughput: throughput,
      p50: stats.p50,
      p95: stats.p95,
      p99: stats.p99
    }
  end

  # ------------------------------------------------------------
  # MAIN
  # ------------------------------------------------------------

  def run do
    Application.ensure_all_started(:exla)
    Application.ensure_all_started(:bumblebee)

    results =
      for batch <- @batch_sizes,
          concurrency <- @concurrency_levels do
        run_case(batch, concurrency)
      end

    IO.puts("")
    IO.puts("================ FINAL =================")

    Enum.each(results, fn r ->
      IO.puts(
        "batch=#{r.batch} " <>
          "conc=#{r.concurrency} " <>
          "thr=#{Float.round(r.throughput, 2)} " <>
          "p95=#{Float.round(r.p95, 2)}ms"
      )
    end)
  end
end

FullNxBench.run()
