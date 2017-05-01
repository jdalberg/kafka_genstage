# KafkaGenStage

A GenStage producer that produces events generated from a kafka topic.

## Example of use

In a GenStage chain, you can start this module as you would a "normal" GenStage
producer by use of the KafkaGenStage.start_link(kafkaOptions)

The kafkaOptions currently handled are (with defaults given):

  :hosts - [localhost: 9092]
  :topics - ["no_topic"]
  :group - "kgs_cg"
  :nof_clients - 2

The group is used because octets are acked in kafka, so kafka, based on the consumer group
given takes care of handling what has been seen and what has not.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kafka_genstage` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:kafka_genstage, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/kafka_genstage](https://hexdocs.pm/kafka_genstage).

