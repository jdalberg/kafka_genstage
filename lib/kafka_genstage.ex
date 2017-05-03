defmodule KafkaGenStage do
  use GenStage

  require Record
  import Record, only: [defrecord: 2, extract: 2]
  defrecord :kafka_message, extract(:kafka_message, from_lib: "brod/include/brod.hrl")

  @moduledoc """

  A module that consumes data from Kafka and injects them
  into a GenStage Producer

  This allows GenStage Consumer-Producers to use a Kafka
  topic as a regular GenStage data source.

  For the Kafka integration it will use the brod package. It
  will start a number of clients specified in the start_link.

  The subscribers will receive messages from the kafka broker, and
  send it into the genstage using a "call".

  The messages will be stacked up in the internal state of the GenStage, and delived
  on demand from GenStage consumers.

  """

  @doc """

  Starts the KafkaGenStage with the options.

  The options handled by the module arei (defaults shown).

  :hosts - [localhost: 9092]
  :topics - ["no_topic"]
  :group - "kgs_cg"
  :nof_clients - 2
  :begin_offset - :latest
    This argument is given directly to the brod client, so it ca be
    [:earliest, :latest]

  Given as a keyword lists, i.e.

  KafkaGenStage.start_link( topics: ["my_topic"], hosts: [my_broker.example.com: 9092] )

  """
  def start_link( kafkaOptions ) do
    GenStage.start_link( KafkaGenStage, kafkaOptions )
  end

  @doc """

  The init function for the GenStage server.

  """
  def init(kafkaOptions) do
    # Setup the kafka consumer.
    bootstrapConsumer( kafkaOptions )
    {:producer, %{msg_stack: []}}
  end

  @doc """

  The GenStage producer function.

  It simply picks messages out of state, and removes them
  from the internal list in state.

  """
  def handle_demand(nof_wanted, state) when nof_wanted > 0 do
    {head, rest} = Enum.split(state.msg_stack, nof_wanted)
    {:noreply, head, %{state | msg_stack: rest}}
  end

  @doc """

  An API method that stacks a new kafka message in the state, so that it
  can be picked off there on demand.

  """
  def handle_call({:message, message}, _from, state ) do
    {:reply, :ok, [message], %{state | msg_stack: state.msg_stack ++ [message]}}
  end

  @doc """

  The Group Subscriber init callback

  """
  def init(_group_id, _callback_init_args = {client_id, topics, gs_pid}) do
    handlers = spawn_message_handlers(client_id, topics, gs_pid)
    {:ok, %{handlers: handlers}}
  end

  @doc """

  brod_group_subscriber callback

  Called by the subscriber, this is where brod leaves messages.

  """
  def handle_message(topic, partition, message, %{handlers: handlers} = state) do
    pid = handlers["#{topic}-#{partition}"]
    ## send the message to message handler process for async processing
    send pid, message
    ## or return {:ok, :ack, state} in case message can be handled synchronously here
    {:ok, state}
  end

  @doc """

  This is where messages from kafka ends up before they are sent into
  the GenStage and stacked.

  """
  def message_handler_loop(topic, partition, subscriber_pid, genstage_pid) do
    receive do
      msg ->
        message = Enum.into(kafka_message(msg), %{})

        # Send the message into the GenStage API
        GenStage.call( genstage_pid, {:message, message} )

        ## send the async ack to group subscriber
        ## the offset will be eventually committed to kafka
        :brod_group_subscriber.ack(subscriber_pid, topic, partition, message.offset)
        __MODULE__.message_handler_loop(topic, partition, subscriber_pid, genstage_pid)
    after
      1000 ->
        __MODULE__.message_handler_loop(topic, partition, subscriber_pid, genstage_pid)
    end
  end


  # Setup a group consumer on all partitions for the topic given.
  defp bootstrapConsumer(kafka_options) do
    kafka_hosts = Keyword.get(kafka_options, :host, [localhost: 9092])
    kafka_topics = Keyword.get(kafka_options, :topics, ["no_topic"])
    consumer_group_name = Keyword.get(kafka_options, :group, "kgs_cg")
    nof_clients = Keyword.get(kafka_options, :nof_clients, 2)
    begin_offset = Keyword.get(kafka_options, :begin_offset, :latest)

    kafka_clients = for i <- 1..nof_clients, do: String.to_atom("kgc_client_#{i}")

    :ok = bootstrapSubscribers(kafka_clients, kafka_hosts, consumer_group_name, kafka_topics, begin_offset)
  end

  defp bootstrapSubscribers([], _kafka_hosts, _group_id, _topics, _begin_offset), do: :ok
  defp bootstrapSubscribers([client_id | rest], kafka_hosts, group_id, topics, begin_offset) do
    :ok = :brod.start_client(kafka_hosts, client_id, _client_config=[])
    group_config = [offset_commit_policy: :commit_to_kafka_v2,
                    offset_commit_interval_seconds: 5,
                    rejoin_delay_seconds: 2 ]

    {:ok, _subscriber} = :brod.start_link_group_subscriber(client_id, group_id, topics, group_config,
                                        _consumer_config = [begin_offset: begin_offset],
                                        _callback_module = __MODULE__,
                                        _callback_init_args = {client_id, topics, self()})
    bootstrapSubscribers(rest, kafka_hosts, group_id, topics, begin_offset)
  end

  defp spawn_message_handlers(_client_id, [], _gs_pid), do: %{}
  defp spawn_message_handlers(client_id, [topic | rest], gs_pid) do
    {:ok, partition_count} = :brod.get_partitions_count(client_id, topic)
    handlers = Enum.reduce :lists.seq(0, partition_count-1), %{}, fn partition, acc ->
      handler_pid = spawn_link(__MODULE__, :message_handler_loop, [topic, partition, self(), gs_pid])
      Map.put(acc, "#{topic}-#{partition}", handler_pid)
    end
    Map.merge(handlers, spawn_message_handlers(client_id, rest, gs_pid))
  end

end
