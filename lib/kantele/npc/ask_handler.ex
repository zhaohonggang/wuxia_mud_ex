defmodule Kantele.NPC.AskHandler do
  @moduledoc """
  NPC 问询处理器行为（对应 LPC ask/1 与收徒/授技/给物链）

  实现模块需定义：
    @ask_specs %{
      "keyword" => %{
        check: fn(asker, npc) -> :ok | {:error, msg} end,
        execute: fn(asker, npc) -> :ok | {:error, msg} end,
        effects: [{:give_item, item_id}, {:improve_skill, skill, lvl}, ...]
      }
    }
  """

  @callback ask_specs() :: map()

  @callback check(asker :: map(), npc :: map(), keyword :: String.t()) ::
              :ok | {:error, String.t()}

  @callback execute(asker :: map(), npc :: map(), keyword :: String.t()) ::
              :ok | {:error, String.t()}

  @callback effects(asker :: map(), npc :: map(), keyword :: String.t()) :: [term()]
end
