defmodule Queutils.BlockingQueueTest do
  use ExUnit.Case
  alias Queutils.BlockingQueue, as: BQ
  doctest Queutils.BlockingQueue

  test "increments pushed_count" do
    queue = :pushed_count_test

    BQ.start_link(name: queue)
    assert BQ.pushed_count(queue) == 0

    :ok = BQ.push(queue, [])
    assert BQ.pushed_count(queue) == 1

    _ = BQ.pop(queue)
    assert BQ.pushed_count(queue) == 1

    :ok = BQ.push(queue, [])
    assert BQ.pushed_count(queue) == 2

    _ = BQ.pop(queue)
    assert BQ.pushed_count(queue) == 2
  end

  test "increments popped_count" do
    queue = :popped_count_test

    BQ.start_link(name: queue)
    assert BQ.popped_count(queue) == 0

    :ok = BQ.push(queue, [])
    assert BQ.popped_count(queue) == 0

    _ = BQ.pop(queue)
    assert BQ.popped_count(queue) == 1

    :ok = BQ.push(queue, [])
    assert BQ.popped_count(queue) == 1

    _ = BQ.pop(queue)
    assert BQ.popped_count(queue) == 2
  end

  test "popped_count doesn't incremement for empty pops" do
    queue = :popped_empty_test

    BQ.start_link(name: queue)
    _ = BQ.pop(queue)
    assert BQ.popped_count(queue) == 0
  end

  test "popped_count only increments partially for partial pops" do
    queue = :popped_empty_test

    BQ.start_link(name: queue)

    :ok = BQ.push(queue, [])
    _ = BQ.pop(queue, 2)
    assert BQ.popped_count(queue) == 1
  end

  test "two queues can exist without conflicts" do
    BQ.start_link(name: MyFirstQueue)
    BQ.start_link(name: MySecondQueue)

    first_ref = make_ref()
    second_ref = make_ref()

    BQ.push(MyFirstQueue, first_ref)
    BQ.push(MySecondQueue, second_ref)

    [first_actual] = BQ.pop(MyFirstQueue)
    [second_actual] = BQ.pop(MySecondQueue)

    assert first_actual == first_ref
    assert second_actual == second_ref
  end
end
