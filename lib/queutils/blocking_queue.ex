defmodule Queutils.BlockingQueue do
  use GenServer

  @moduledoc """
  A queue with a fixed length that blocks on `Queutils.BlockingQueue.push/2` if the queue is full.

  ## Usage

  Add it to your application supervisor's `start/2` function, like this:

      def start(_type, _args) do
        children = [
          ...
          {Queutils.BlockingQueue, name: MessageQueue, max_length: 10_000},
          ...
        ]

        opts = [strategy: :one_for_one, name: MyApplication.Supervisor]
        Supervisor.start_link(children, opts)
      end

  Then you can push and pop from the queue like this:

      :ok = Queutils.Blockingqueue.push(MessageQueue, :my_message)
      [:my_message] = Queutils.Blockingqueue.pop(MessageQueue, 1)

  Use with `Queutils.BlockingQueueProducer` for more fun,
  or use `Queutils.BlockingProducer` for the effect of both.

  ## Options

    - `:name` - the ID of the queue. This will be the first argument to the `push/2` function. Default is `BlockingQueue`.
    - `:max_length` - The maximum number of messages that this process will store until it starts blocking. Default is 1,000.
  """

  @doc """
  Start a blocking queue process.

  ## Options

    - `:name` - the ID of the queue. This will be the first argument to the `push/2` function. Default is `BlockingQueue`.
    - `:max_length` - The maximum number of messages that this process will store until it starts blocking. Default is 1,000.
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, BlockingQueue),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def init(opts) do
    max_length = Keyword.get(opts, :max_length, 1_000)
    {:ok, %{max_length: max_length, queue: [], waiting: []}}
  end

  @doc """
  Push an item onto the queue.
  This function will block if the queue is full, and unblock once it's not.
  """
  def push(queue, msg) do
    GenServer.call(queue, {:push, msg})
  end

  @doc """
  Pop an item off of the queue. Never blocks, and returns a list.
  The returned list will be empty if the queue is empty.
  """
  def pop(queue, count \\ 1) do
    GenServer.call(queue, {:pop, count})
  end

  @doc """
  Get the current length of the queue.
  """
  def length(queue) do
    GenServer.call(queue, :length)
  end

  def handle_call(:length, _from, state) do
    {:reply, Enum.count(state.queue), state}
  end

  def handle_call({:push, msg}, from, state) do
    if Enum.count(state.queue) >= state.max_length do
      waiting = state.waiting ++ [{from, msg}]
      {:noreply, %{state | waiting: waiting}}
    else
      queue = state.queue ++ [msg]
      {:reply, :ok, %{state | queue: queue}}
    end
  end

  def handle_call({:pop, count}, _from, state) do
    {popped, remaining} = Enum.split(state.queue, count)
    {popped_waiters, still_waiting} = Enum.split(state.waiting, count)

    msgs_from_waiters = Enum.map(popped_waiters, fn {from, msg} ->
      GenServer.reply(from, :ok)
      msg
    end)

    queue = remaining ++ msgs_from_waiters

    {:reply, popped, %{state | queue: queue, waiting: still_waiting}}
  end
end