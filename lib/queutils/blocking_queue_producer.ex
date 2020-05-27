defmodule Queutils.BlockingQueueProducer do
  use GenStage
  require Logger

  @moduledoc """
  A `GenStage` producer that polls a `Queutils.BlockingQueue` at a fixed interval,
  emitting any events on the queue.

  ## Usage

  Add it to your application supervisor's `start/2` function, after the queue it pulls from, like this:

      def start(_type, _args) do
        children = [
          ...
          {Queutils.BlockingQueue, name: MessageQueue, max_length: 10_000},
          {Queutils.BlockingQueueProducer, name: MessageProducer},
          ...
        ]

        opts = [strategy: :one_for_one, name: MyApplication.Supervisor]
        Supervisor.start_link(children, opts)
      end

  The subscribe a consumer to it, like any other `GenStage` producer.

      def init(_opts) do
        {:consumer, :my_consumer_state, [subscribe_to: MessageProducer]}
      end

  ## Options

    - `:name` - the ID of the queue. This will be the first argument to the `push/2` function. Default is `BlockingProducer`.
    - `:max_length` - The maximum number of messages that this process will store until it starts blocking. Default is 1,000.
    - `:dispatcher` - The `GenStage` dispatcher that this producer should use. Default is `GenStage.DemandDispatcher`.
  """

  def start_link(opts) do
    name = Keyword.get(opts, :name, BlockingQueueProducer)
    GenStage.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, BlockingQueueProducer),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, 250)
    dispatcher = Keyword.get(opts, :dispatcher, GenStage.DemandDispatcher)
    queue = Keyword.get(opts, :queue, BlockingQueue)
    Process.send_after(self(), :poll, poll_interval)
    {:producer, %{queue: queue, demand: 0, poll_interval: poll_interval}, dispatcher: dispatcher}
  end

  @impl true
  def handle_info(:poll, state) do
    events = Queutils.BlockingQueue.pop(state.queue, state.demand)
    remaining_demand = state.demand - Enum.count(events)

    Process.send_after(self(), :poll, state.poll_interval)
    {:noreply, events, %{state | demand: remaining_demand}}
  end

  @impl true
  def handle_demand(demand, state) do
    total_demand = demand + state.demand
    events = Queutils.BlockingQueue.pop(state.queue, total_demand)
    remaining_demand = total_demand - Enum.count(events)
    {:noreply, events, %{state | demand: remaining_demand}}
  end
end
