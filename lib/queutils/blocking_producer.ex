defmodule Queutils.BlockingProducer do
  use GenStage

  @moduledoc """
  A `GenStage` producer that acts as a blocking queue, with a fixed length.
  Blocks any time `Queutils.BlockingProducer.push/2` is called when the queue
  is at its maximum length.

  This can be used as an entry-point to a `GenStage` pipeline, since the
  max queue length provides for back-pressure.
  You can even set the queue's length to zero in order to block all pushes
  until demand comes in.


  ## Usage

  Add it to your application supervisor's `start/2` function like this:

      def start(_type, _args) do
        children = [
          ...
          {Queutils.BlockingProducer, name: MessageProducer, max_length: 10_000},
          ...
        ]

        opts = [strategy: :one_for_one, name: MyApplication.Supervisor]
        Supervisor.start_link(children, opts)
      end

  Then, you can push messages to the queue like this:

      :ok = Queutils.BlockingProducer.push(MessageProducer, :my_message)


  Broadway users be forewared! A Broadway module needs to start its producer itself,
  so it's not possible to customize the process ID a la the `:name` option documented below.
  If you're in that boat, you should use a `Queutils.BlockingQueue` along with
  a `Queutils.BlockingQueueProducer`, so you can customize your reference to your `BlockingQueue`.

  ## Options

    - `:name` - the ID of the queue. This will be the first argument to the `push/2` function.
    - `:max_length` - The maximum number of messages that this process will store until it starts blocking. Default is 1,000.
    - `:dispatcher` - The `GenStage` dispatcher that this producer should use. Default is `GenStage.DemandDispatcher`.
  """

  def start_link(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> GenStage.start_link(__MODULE__, opts, name: name)
      :error -> GenStage.start_link(__MODULE__, opts)
    end
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, Queutils.BlockingProducer),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Push an item onto the queue.
  This function will block if the queue is full, and unblock once it's not.
  """
  @spec push(term(), term()) :: :ok
  def push(queue, msg) do
    GenStage.call(queue, {:push, msg})
  end

  @doc """
  Get the number of items currently sitting in a queue.
  """
  def length(queue) do
    GenStage.call(queue, :length)
  end

  @doc """
  Get the number of blocked processes waiting to push to a queue.
  """
  def waiting_count(queue) do
    GenStage.call(queue, :waiting_count)
  end

  @doc """
  Get the total count of messages that have been pushed to a queue over its lifetime.
  """
  def pushed_count(queue) do
    GenStage.call(queue, :pushed_count)
  end


  @doc """
  Get the total count of messages that have been popped from a queue over its lifetime.
  """
  def popped_count(queue) do
    GenStage.call(queue, :popped_count)
  end

  @impl true
  def init(opts) do
    dispatcher = Keyword.get(opts, :dispatcher, GenStage.DemandDispatcher)
    max_length = Keyword.get(opts, :max_length, 1_000)
    unless max_length >= 0 do
      raise "Invalid argument :max_length. Must be an integer zero or greater, but was #{inspect max_length}"
    end
    {:producer, %{queue: [], waiting: [], demand: 0, max_length: max_length, pushed_count: 0, popped_count: 0}, dispatcher: dispatcher}
  end

  @impl true
  def handle_call({:push, msg}, from, state) do
    :ok = validate_state(state)
    cond do
      state.demand > 0 ->
        remaining_demand = state.demand - 1
        {:reply, :ok, [msg], %{state | demand: remaining_demand, pushed_count: state.pushed_count + 1, popped_count: state.popped_count + 1}}
      Enum.count(state.queue) >= state.max_length ->
        waiting = state.waiting ++ [{from, msg}]
        {:noreply, [], %{state | waiting: waiting}}
      true ->
        queue = state.queue ++ [msg]
        {:reply, :ok, [], %{state | queue: queue, pushed_count: state.pushed_count + 1}}
    end
  end

  def handle_call(:length, _from, state) do
    {:reply, Kernel.length(state.queue), [], state}
  end

  def handle_call(:waiting_count, _from, state) do
    {:reply, Kernel.length(state.waiting), [], state}
  end

  def handle_call(:pushed_count, _from, state) do
    {:reply, state.pushed_count, [], state}
  end

  def handle_call(:popped_count, _from, state) do
    {:reply, state.popped_count, [], state}
  end

  @impl true
  def handle_demand(demand, state) do
    :ok = validate_state(state)

    total_demand = demand + state.demand

    {popped, remaining} = Enum.split(state.queue, total_demand)
    {popped_waiters, still_waiting} = Enum.split(state.waiting, total_demand)

    msgs_from_waiters = Enum.map(popped_waiters, fn {from, msg} ->
      GenStage.reply(from, :ok)
      msg
    end)

    queue = remaining ++ msgs_from_waiters
    remaining_demand = total_demand - Enum.count(queue)
    new_pushes = Kernel.length(msgs_from_waiters)
    new_pops = Kernel.length(popped)

    {:noreply, popped, %{state | demand: remaining_demand, queue: queue, waiting: still_waiting, pushed_count: state.pushed_count + new_pushes, popped_count: state.popped_count + new_pops}}
  end

  defp validate_state(state) do
    # If we have a non-zero demand, it is assumed that we will not have
    # anyone waiting and that the queue is empty, since we would have
    # popped off all those messages before building up any demand.

    cond do
      state.demand < 0 ->
        raise "Incorrect state: BlockingProducer has a negative demand (demand is #{inspect state.demand})."
      state.demand > 0 && not Enum.empty?(state.queue) ->
        raise "Incorrect state: BlockingProducer has demand but also has items in its queue."
      state.demand > 0 && not Enum.empty?(state.waiting) ->
        raise "Incorrect state: BlockingProducer has demand but also has processes waiting to insert."
      state.pushed_count < state.popped_count ->
        raise "Incorrect state: pushed_count is less than popped_count (pushed: #{state.pushed_count}, popped: #{state.popped_count})"
      true -> :ok
    end
  end
end
