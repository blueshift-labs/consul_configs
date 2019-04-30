defmodule ConsulConfigs.MixProject do
  use Mix.Project

  def project do
    [
      app: :consul_configs,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets],
      mod: {ConsulConfigs.Application, []}
    ]
  end

  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:yaml_elixir, "~> 2.1"},
      {:jason, "~> 1.1.2"}
    ]
  end
end
