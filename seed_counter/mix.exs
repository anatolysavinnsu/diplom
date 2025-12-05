defmodule SeedCounter.MixProject do
  use Mix.Project

  def project do
    [
      app: :seed_counter,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SeedCounter.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bumblebee, "~> 0.6"},
      {:exla, "~> 0.7"},
      {:nx, "~> 0.7"},
      {:stb_image, "~> 0.6"}
    ]
  end
end
