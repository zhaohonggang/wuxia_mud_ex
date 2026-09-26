defmodule Kantele.World.LPCConverter.AST do
  @moduledoc """
  AST structure for LPC converter.
  """

  defstruct [
    :inherits,
    :create_fn,
    :other_fns,
    :globals,
    :heredocs,
    :source_path,
    :base_path,
    :valid_leave,
    :exit_vetoes,
    :function_calls,
    :enter,
    :greetings,
    :accept,
    :guard,
    :engage,
    :unhandled,
    :inherit_files
  ]

  @type t :: %__MODULE__{
    inherits: [String.t()],
    create_fn: map(),
    other_fns: [map()],
    globals: map(),
    heredocs: map(),
    source_path: String.t(),
    base_path: String.t(),
    valid_leave: map() | nil,
    function_calls: map(),
    enter: map() | nil,
    greetings: [String.t()] | nil,
    accept: [map()] | nil,
    inherit_files: [String.t()]
  }

  def new(params) do
    struct(__MODULE__, params)
  end
end