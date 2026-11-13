defmodule Kantele.NPC.Niutou do
  @moduledoc """
  牛头 NPC 问询处理器（对应 LPC `d/death/npc/niutou.c`）。

  牛头守在奈河桥北端（qiao2），向 north 移动时会被 valid_leave 拦截。
  玩家处于幽灵态时可向牛头询问：

  - "还阳"：牛头拒绝，告知需先完成地府流程、找白无常
  - "奈河桥" / "牛头" / "niutou"：牛头的冷冰回应

  牛头本身不处理还阳（还阳由白无常 / `Kantele.NPC.Wuchang` 负责），
  只负责拦截和回话。
  """

  @behaviour Kantele.NPC.AskHandler

  @impl true
  def ask_specs do
    %{
      "还阳" => niutou_spec("还阳"),
      "奈河桥" => niutou_spec("奈河桥"),
      "牛头" => niutou_spec("牛头"),
      "niutou" => niutou_spec("牛头")
    }
  end

  defp niutou_spec(keyword) do
    %{
      check: &niutou_check/2,
      execute: fn asker, _npc -> niutou_execute(asker, _npc, keyword) end,
      effects: []
    }
  end

  @impl true
  def check(asker, _npc, _keyword), do: niutou_check(asker, _npc)

  @impl true
  def execute(asker, _npc, keyword), do: dispatch_execute(asker, _npc, keyword)

  @impl true
  def effects(_asker, _npc, _keyword), do: []

  defp dispatch_execute(asker, _npc, keyword) do
    case ask_specs()[keyword] do
      nil ->
        {:error, "牛头闭口不语。"}

      spec ->
        spec.execute.(asker, _npc)
    end
  end

  # ---- check ----

  defp niutou_check(asker, _npc) do
    cond do
      # 仅限幽灵态
      Map.get(asker.meta.env || %{}, :ghost) != true ->
        {:error, "牛头喝道：你是阳人，冥府不容你在此久留，快回去罢！\n"}

      true ->
        :ok
    end
  end

  # ---- execute ----

  defp niutou_execute(asker, _npc, keyword) do
    cond do
      keyword == "还阳" ->
        {:ok,
         "牛头厉声道：还阳之事自有白无常掌管，与我何干？\n你若想回阳世，去找鬼门关的白无常「ask 白无常 还阳」吧。\n"}

      true ->
        {:ok,
         "牛头看了你一眼，喝道：奈河桥北端由我把关，你这游魂休想越雷池一步。\n"}
    end
  end
end
