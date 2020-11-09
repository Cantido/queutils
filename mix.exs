defmodule Queutils.MixProject do
  use Mix.Project

  def project do
    [
      app: :queutils,
      version: "1.2.1",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Handy little queues and producers.",
      source_url: "https://github.com/cantido/queutils",
      homepage_url: "https://github.com/cantido/queutils",
      package: [
        maintainers: ["Rosa Richter"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/cantido/queutils"},
      ],
      docs: [
        main: "Queutils",
        source_url: "https://github.com/cantido/queutils",
        extras: [
          "README.md"
        ]
      ]
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
      {:gen_stage, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
