defmodule KafkaGenStageTest do
  use ExUnit.Case
  doctest KafkaGenStage
  @test_topic "test_topic"
  @test_brod_client_id :kgs_test_client_1

  setup_all do
    :ok = :brod.start_client([localhost: 9092], @test_brod_client_id, _client_config=[])
    :ok = :brod.start_producer(@test_brod_client_id, @test_topic, _producer_config=[])

    on_exit fn ->
      :brod.stop_client(@test_brod_client_id)
    end
  end

  test "Simple Kafka Message" do
    if isKafkaRunning() == :ok do
      # Check if the test kafka topic is present.
      if isTestTopicPresent() do
        {:ok, kgs} = GenStage.start_link(KafkaGenStage, hosts: [localhost: 9092], topics: [@test_topic], group: "test_group", begin_offset: :latest)
        {:ok, tc} = GenStage.start_link(TestConsumer, self())

        # Subscribe thet test gs consumer to the KafkaGenStage producer
        GenStage.sync_subscribe(tc, to: kgs)

        :timer.sleep(100) # because it takes time to setup GenStage i guess.

        produceKafkaValue("test_key", "test_value")

        assert_receive {:ack, "test_key"}, 1000
      else
        IO.puts "Kafka does not appear to have the test topic configured...test skipped"
      end
    else
      IO.puts "Kafka does not appear to be running on localhost...test skipped"
    end
  end

  # Checks if kafka is running by telnetting
  # to localhost:9092
  defp isKafkaRunning() do
    case :gen_tcp.connect('localhost', 9092, []) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
      {:error, _reason} ->
        :error
    end
  end

  defp isTestTopicPresent() do
    case :brod.get_partitions_count(@test_brod_client_id, @test_topic) do
      {:ok, _partition_count} -> true
      weird -> IO.inspect weird
               false
    end
  end

  defp produceKafkaValue(key,value) do
    :brod.produce_sync(@test_brod_client_id, @test_topic, 0, key, value)
  end
end

defmodule TestConsumer do
  use GenStage

  def init(test_pid) do
    {:consumer, test_pid}
  end

  def handle_events(events, _from, test_pid) do
    IO.puts("handle_events in TestConsumer called: #{inspect events}")
    case events do
      [%{key: key}] ->
        send test_pid, {:ack, key}
      _ ->
        send test_pid, {:ack, "invalid_event"}
    end
    {:noreply, [], test_pid}
  end
end
