defmodule GTFSRouteBranching.MixProject do
  use Mix.Project

  def project do
    [
      app: :gtfs_route_branching,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: LcovEx, ignore_paths: ["test/"]],
      name: "GTFS Route Branching",
      source_url: "https://github.com/mbta/gtfs_route_branching",
      homepage_url: "https://mbta.github.io/gtfs_route_branching",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:ex_machina, "~> 2.8", only: :test},
      {:lcov_ex, "~> 0.3", only: [:test], runtime: false},
      {:uniq, "~> 0.6", only: :test}
    ]
  end

  defp docs do
    [
      main: "GTFSRouteBranching",
      formatters: ["html"]
    ]
  end
end
