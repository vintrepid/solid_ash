defmodule SolidAsh.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/vintrepid/solid_ash"

  def project do
    [
      app: :solid_ash,
      version: @version,
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Solid pod storage and authorization primitives for Ash/Phoenix apps",
      # CTR is unreachable: every vault key is validated as AES-256-GCM.
      # See SECURITY.md and the encryption rejection/tampering tests.
      hex: [ignore_advisories: ["EEF-CVE-2026-95105"]],
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
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ash, "~> 3.37 and >= 3.37.2"},
      # JournalAsh is independent of SolidAsh; this immutable public commit is
      # the lower-layer journal contract validated by this library.
      {:journal_ash,
       github: "vintrepid/journal_ash", ref: "6f87f08e0398ebba66ccf266dd4a243248dcec5e"},
      # Upstream 4.15 caps Assent below the Apple callback security fix.
      # This tested fork is temporarily required for the unreleased dependency
      # compatibility fix (EEF-CVE-2026-117656); return to Hex once released.
      {:ash_authentication,
       git: "https://github.com/vintrepid/ash_authentication.git",
       ref: "c28f9396cea7835f0ef3b92ceee303770075bde7"},
      {:ash_postgres, "~> 2.15 and >= 2.15.2"},
      {:ash_cloak, "~> 0.5.0"},
      # Keep the documented security floors even in a host with older locks.
      {:ash_sql, "~> 0.8.4"},
      {:postgrex, "~> 0.22.4"},
      {:cloak, "~> 1.1 and >= 1.1.4"},
      {:jason, "~> 1.4 and >= 1.4.5"},
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false}
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
