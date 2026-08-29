defmodule Kantele.NPC.ZhangSanfeng do
  @moduledoc """
  张三丰 NPC 问询处理器（对应 class_wudang_zhang 的问鹤嘴劲→收徒→授真武剑链）

  关键词：
    - "鹤嘴劲"：入门测试
    - "收徒"：拜师
    - "真武剑"：师门唯一物品发放
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.Stats
  alias Kantele.Character.Presence
  alias Kantele.Combat.Skills

  @impl true
  def ask_specs do
    %{
      "鹤嘴劲" => %{
        check: fn _asker, _npc -> :ok end,
        execute: fn asker, _npc ->
          send(asker.pid, {:room_message, "张三丰点头道：「鹤嘴劲乃本派入门心法，你可愿拜入吾门？」\n"})
          :ok
        end,
        effects: []
      },

      "收徒" => %{
        check: fn asker, _npc ->
          cond do
            Stats.skill(asker.meta.stats, "taiji-quan") >= 1 ->
              :ok
            true ->
              {:error, "你的太极拳火候不足，老道暂不收徒。\n"}
          end
        end,
        execute: fn asker, npc ->
          asker = Map.put(asker.meta, :family, "wudang")
          npc = Map.put(npc.meta, :disciples, [asker.id | Map.get(npc.meta, :disciples, [])])
          send(asker.pid, {:room_message, "张三丰大笑：「好徒儿！从此你便是吾武当派第 N 代弟子。」\n"})
          :ok
        end,
        effects: [{:set_faction, "wudang"}, {:add_gongxian, 10}]
      },

      "真武剑" => %{
        check: fn asker, _npc ->
          cond do
            Map.get(asker.meta, :family) == "wudang" ->
              :ok
            true ->
              {:error, "非本派弟子，不可领真武剑。\n"}
          end
        end,
        execute: fn asker, _npc ->
          # 唯一物品注册表占位：实际落地需接入 Kantele.Item.Registry
          send(asker.pid, {:room_message, "张三丰从怀中摸出一柄古剑，郑重塞入你手中：「真武剑赠予你，切记护道安民。」\n"})
          :ok
        end,
        effects: [{:give_unique_item, "zhenwu_sword"}]
      }
    }
  end

  @impl true
  def check(asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil -> {:error, "张三丰摇头：「老道不懂你在说什么。」\n"}
      spec -> spec.check.(asker, npc)
    end
  end

  @impl true
  def execute(asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil -> {:error, "无此问询。"}
      spec -> spec.execute.(asker, npc)
    end
  end

  @impl true
  def effects(asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil -> []
      spec -> spec.effects
    end
  end
end