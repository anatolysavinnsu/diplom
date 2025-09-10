defmodule PlantClassifier.InternalQueue do
  use GenServer

  # API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :queue.new(), name: __MODULE__)
  end

  def push(task) do
    GenServer.cast(__MODULE__, {:push, task})
  end

  def pop do
    GenServer.call(__MODULE__, :pop, :infinity)
  end

  # Callbacks
  @impl true
  def init(queue) do
    {:ok, queue}
  end

  @impl true
  def handle_cast({:push, task}, queue) do
    {:noreply, :queue.in(task, queue)}
  end

  @impl true
  def handle_call(:pop, from, queue) do
    case :queue.out(queue) do
      {{:value, task}, new_queue} ->
        {:reply, task, new_queue}

      {:empty, _} ->
        # Нет задач — ждём, не блокируем GenServer
        Process.send_after(self(), {:wake_up, from}, 5)
        {:noreply, queue}
    end
  end

  @impl true
  def handle_info({:wake_up, from}, queue) do
    case :queue.out(queue) do
      {{:value, task}, new_queue} ->
        GenServer.reply(from, task)
        {:noreply, new_queue}

      {:empty, _} ->
        Process.send_after(self(), {:wake_up, from}, 5)
        {:noreply, queue}
    end
  end
end
