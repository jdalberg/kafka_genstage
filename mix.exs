defmodule KafkaGenStage.Mixfile do
  use Mix.Project

  def project do
    [app: :kafka_genstage,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:gen_stage, "~> 0.11.0"},
      {:brod, "~> 2.3.6"}
    ]
  end
end
