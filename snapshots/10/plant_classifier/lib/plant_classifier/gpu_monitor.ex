defmodule PlantClassifier.GpuMonitor do
  @moduledoc """
  Мониторинг состояния GPU и информации о кластере.
  """

  def get_metrics do
    case System.get_env("NODE_ROLE") do
      "gpu" ->
        # Здесь будет реальный вызов nvidia-smi после настройки GPU
        %{status: "no_gpu_data", error: "nvidia-smi not configured yet"}

      _ ->
        %{status: "cpu_only", info: "This node is CPU-only"}
    end
  end

  def available? do
    System.get_env("NODE_ROLE") == "gpu"
  end
end
