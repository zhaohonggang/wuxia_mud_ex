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
    :function_calls
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
    function_calls: map()
  }

  def new(params) do
    struct(__MODULE__, params)
  end
end