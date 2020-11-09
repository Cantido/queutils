# Queutils

[![Hex.pm](https://img.shields.io/hexpm/v/queutils)](https://hex.pm/packages/queutils/)
![Elixir CI](https://github.com/Cantido/queutils/workflows/Elixir%20CI/badge.svg)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg)](https://github.com/RichardLitt/standard-readme)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](code_of_conduct.md)

Handy little queues and producers that make using `GenStage` or `Broadway` a breeze.

Getting events into a `GenStage` or `Broadway` pipeline is more difficult than it seems at first glance.
Any message producer based on `GenStage` needs to track demand,
and emit events as it receives them if there is surplus demand.
Also, any producer implementation needs to provide back-pressure,
a key part of `GenStage` and `Broadway`'s design.
That's why a standalone blocking queue process is most the most ideal producer for these libraries.

- Decouples message producers and consumers, so producers do not need to wait for the consumer to be ready
- Blocks when full, so producers don't keep producing messages if the consumer is overwhelmed
- Tracks demand, and immediately emits events if demand is pending

This library also provides a blocking queue implementation that can be used in pure Elixir.

## Installation

This library is [available in Hex](https://hex.pm/docs/publish), and the package can be installed
by adding `queutils` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:queutils, "~> 1.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and can be found online at [https://hexdocs.pm/queutils](https://hexdocs.pm/queutils).

## Usage

If you just want a queue to communicate between processes, use a `Queutils.BlockingQueue`.
This module implements a queue with a fixed length,
and any calls to `Queutils.BlockingQueue.push/2` will block until the queue has room again.

If you're working with `GenStage`, you probably want to use `Queutils.BlockingProducer`.
This module is just like a `Queutils.BlockingQueue`,
but it also provides callbacks that let a `GenStage` consumer subscribe to it.
This way you can push messages into a `GenStage` pipeline.

Lastly, a `Queutils.BlockingQueueProducer` acts just like a `Queutils.BlockingProducer`,
except you need to provide the queue yourself.
This is the module to use if you're working with `Broadway`,
because `Broadway` stages needs to start up their producers themselves.

### With plain Elixir

Add `Queutils.BlockingQueue` to your application supervisor's `start/2` function, like this:

```elixir
def start(_type, _args) do
  children = [
    {Queutils.BlockingQueue, name: MessageQueue, max_length: 10_000},
  ]

  opts = [strategy: :one_for_one, name: MyApplication.Supervisor]
  Supervisor.start_link(children, opts)
end
```

You can now push messages to the queue like this:

```elixir
:ok = Queutils.BlockingQueue.push(MessageQueue, :my_message)
```

and pop from it like this:

```elixir
:my_message = Queutils.BlockingQueue.pop(MessageQueue)
```

### With GenStage

Add `Queutils.BlockingProducer` to your application supervisor's `start/2` function, like this:

```elixir
def start(_type, _args) do
  children = [
    {Queutils.BlockingProducer, name: MessageProducer, max_length: 10_000}
  ]

  opts = [strategy: :one_for_one, name: MyApplication.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Then, subscribe a `GenStage` to it.

```elixir
def init(:ok) do
  {:consumer, :the_state_does_not_matter, subscribe_to: [MessageProducer]}
end
```

You can now push messages to the queue like this:

```elixir
:ok = Queutils.BlockingProducer.push(MessageProducer, :my_message)
```

### With Broadway

Add `Queutils.BlockingQueue` to your application supervisor's `start/2` function,
just like we're using it with plain Elixir:

```elixir
def start(_type, _args) do
  children = [
    {Queutils.BlockingQueue, name: MessageQueue, max_length: 10_000},
  ]

  opts = [strategy: :one_for_one, name: MyApplication.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Then, add a `Queutils.BlockingQueueProducer` as your `Broadway` stage's producer,
pointing it to the queue you just created.

```elixir
def start_link(_opts) do
  Broadway.start_link(__MODULE__,
    name: __MODULE__,
    producer: [
      module: {Queutils.BlockingQueueProducer, queue: MessageQueue},
      transformer: {MyApplication.Transformer, :transform, []}
    ],
    processors: [
      default: []
    ]
  )
end
```

You will need to add a `:transformer` option to your `Broadway` stage in order to wrap messages in a `Broadway.Message` struct.
It's easy, but needs to be done.
See `Broadway`'s [Custom Producers](https://hexdocs.pm/broadway/custom-producers.html) documentation for details.

You can now push to the queue like this, and your `Broadway` stage will pick it up:

```elixir
:ok = Queutils.Blockingqueue.push(MessageQueue, :my_message)
```

## Maintainer

This project was developed by [Rosa Richter](https://github.com/Cantido).
You can get in touch with her on [Keybase.io](https://keybase.io/cantido).

## Contributing

Questions and pull requests are more than welcome.
I follow Elixir's tenet of bad documentation being a bug,
so if anything is unclear, please [file an issue](https://github.com/Cantido/queutils/issues/new)!
Ideally, my answer to your question will be in an update to the docs.

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for all the details you could ever want about helping me with this project.

Note that this project is released with a Contributor [Code of Conduct](code_of_conduct.md).
By participating in this project you agree to abide by its terms.

## License

MIT License

Copyright 2020 Rosa Richter.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
