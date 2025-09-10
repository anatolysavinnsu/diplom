defmodule PlantClassifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :plant_classifier,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PlantClassifier.Application, []},
      extra_applications: [:logger, :runtime_tools, :oban]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_html, "~> 4.0"},
      {:plug_cowboy, "~> 2.6"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:oban, "~> 2.17"},
      {:nx, "~> 0.10.0"},
      {:exla, "~> 0.10.0"},
      {:bumblebee, "~> 0.6.3"},
      {:stb_image, "~> 0.6"},
      {:libcluster, "~> 3.3"},
      {:hdr_histogram, "~> 0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
