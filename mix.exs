defmodule GTFSRouteBranching.MixProject do
  use Mix.Project

  def project do
    [
      app: :gtfs_route_branching,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:lcov_ex, "~> 0.3", only: [:test], runtime: false}
    ]
  end
end
