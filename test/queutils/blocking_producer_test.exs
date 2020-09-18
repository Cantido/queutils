defmodule Queutils.BlockingProducerTest do
  use ExUnit.Case
  alias Queutils.BlockingProducer
  doctest Queutils.BlockingProducer

  test "pushing with zero demand adds to the queue" do
    pushed_item = make_ref()
    state = %{
      queue: [],
      waiting: [],
      demand: 0,
      max_length: 1_000,
      pushed_count: 0,
      popped_count: 0
    }
    {:reply, :ok, [], new_state} =
      BlockingProducer.handle_call({:push, pushed_item}, nil, state)

    assert new_state.queue == [pushed_item]
    assert new_state.pushed_count == 1
    assert new_state.popped_count == 0
  end

  test "pushing with greather-than-zero demand emits the item immediately" do
    pushed_item = make_ref()
    state = %{
      queue: [],
      waiting: [],
      demand: 1,
      max_length: 1_000,
      pushed_count: 0,
      popped_count: 0
    }
    {:reply, :ok, [^pushed_item], new_state} =
      BlockingProducer.handle_call({:push, pushed_item}, nil, state)

    assert new_state.queue == []
    assert new_state.pushed_count == 1
    assert new_state.popped_count == 1
  end

  test "pushing with no demand and a full queue stores a ref to the caller" do
    pushed_item = make_ref()
    waiter = make_ref()
    state = %{
      queue: [],
      waiting: [],
      demand: 0,
      max_length: 0,
      pushed_count: 0,
      popped_count: 0
    }
    {:noreply, [], new_state} =
      BlockingProducer.handle_call({:push, pushed_item}, waiter, state)

    assert new_state.waiting == [{waiter, pushed_item}]
    assert new_state.pushed_count == 0
    assert new_state.popped_count == 0
  end

  test "pushing onto a zero-length queue with demand emits the event immediately" do
    pushed_item = make_ref()

    state = %{
      queue: [],
      waiting: [],
      demand: 1,
      max_length: 0,
      pushed_count: 0,
      popped_count: 0
    }
    {:reply, :ok, [^pushed_item], new_state} =
      BlockingProducer.handle_call({:push, pushed_item}, nil, state)

    assert new_state.waiting == []
    assert new_state.queue == []
    assert new_state.pushed_count == 1
    assert new_state.popped_count == 1
  end
end
