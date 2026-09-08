defmodule SolidAsh.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/vintrepid/solid_ash"

  def project do
    [
      app: :solid_ash,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Solid pod storage and authorization primitives for Ash/Phoenix apps",
      hex: [ignore_advisories: ["EEF-CVE-2026-32686"]],
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SolidAsh.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.33"},
      # JournalAsh is independent of SolidAsh; this immutable public commit is
      # the lower-layer journal contract validated by this library.
      {:journal_ash,
       github: "vintrepid/journal_ash", ref: "5b151a68dffc62e564bef11f5865b212ab80a339"},
      # SolidAsh follows the public upstream contract. AshLotus may override
      # this with its maintained, compatibility-tested fork.
      {:ash_authentication, "~> 4.0"},
      {:ash_postgres, "~> 2.13"},
      {:ash_cloak, "~> 0.4"},
      # Keep the documented security floors even in a host with older locks.
      {:ash_sql, "~> 0.7 and >= 0.7.1"},
      {:postgrex, "~> 0.22 and >= 0.22.4"},
      {:cloak, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Vince"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(config lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md SECURITY.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "SECURITY.md"]
    ]
  end
end
