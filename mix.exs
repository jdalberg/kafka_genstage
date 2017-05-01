defmodule KafkaGenStage.Mixfile do
  use Mix.Project

  def project do
    [app: :kafka_genstage,
     version: "0.1.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     name: "KafkaGenStage",
     source_url: "https://github.com/jdalberg/kafka_genstage",
     deps: deps()]
  end

  def application do
    []
  end

  defp description do
    """
    A module that makes a kafka topic act as a GenState producer
    """
  end

  defp package do
    [
      name: :kafka_genstage,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Jesper Dalberg"],
      licenses: ["The Unlicense"],
      links: %{"GitHub" => "https://github.com/jdalberg/kafka_genstage"}
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 0.11.0"},
      {:brod, "~> 2.3.6"},
      {:ex_doc, "~> 0.14", only: :dev}
    ]
  end
end
