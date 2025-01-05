defmodule Chord.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :chord,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Chord",
      description: description(),
      source_url: "https://github.com/stefanzvkvc/chord"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:redix, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test},
      {:benchee, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Stefan Zivkovic"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/stefanzvkvc/chord",
        "Documentation" => "https://hexdocs.pm/chord"
      },
      categories: ["State Management", "Real-Time"],
      keywords: ["state synchronization", "delta tracking", "ETS", "Redis", "real-time"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp description() do
    "An Elixir library for real-time state sync and delta tracking, with ETS, Redis, and periodic cleanup support."
  end
end
