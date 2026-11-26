defmodule Kantele.World.KunlunCombatChatTest do
  @moduledoc """
  昆仑派动态文案与战斗闲聊定向测试（Task #758）。

  数据来源：LPC `kungfu/class/kunlun/*.c` 的 `set("chat_chance_combat", 100)` +
  `set("chat_msg_combat", ({ (: perform_action, "..." :), ... }))`，以及
  `hezudao.c` 的 `init()` / `greeting()` 30% 延迟 `play jian-jia`。

  重点锁定：
    1. 8/8 昆仑 NPC 的 chat_chance_combat=100 + chat_msg_combat 逐招载荷；
    2. 何足道 greeting 别名派发（hash id 无法按 id 注册）；
    3. 30% 概率门 + not-fighting 门 + 蒹葭弹琴 vision 文案；
    4. {respect} 由 Helpers.respect/1 动态渲染（见 npc_greeting_test）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Loader
  alias Kantele.World.NpcGreeting

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, alias_key) do
    Enum.find(world.characters, fn c ->
      Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
    end)
  end

  # ---------- 1. 战斗闲聊载荷 ----------

  describe "chat_msg_combat 载荷逐字保留（LPC perform_action/exert_function）" do
    @payloads %{
      "kunlun_banshuxian" => ["sword.wu", "throwing.liu", "cuff.shi", "hand.sun", "recover", "powerup"],
      "kunlun_gaozecheng" => ["cuff.shi", "sword.xun", "recover", "powerup"],
      "kunlun_hetaichong" => ["sword.fanyin", "throwing.liu", "cuff.shi", "hand.sun", "recover", "powerup"],
      "kunlun_hezudao" => ["sword.ni", "sword.riyue", "strike.kong", "recover", "powerup"],
      "kunlun_jiangtao" => ["cuff.shi", "sword.xun", "recover", "powerup"],
      "kunlun_weisiniang" => ["cuff.shi", "sword.xun", "recover", "powerup"],
      "kunlun_xihuazi" => ["cuff.shi", "sword.xun", "recover", "powerup"],
      "kunlun_zhanchun" => ["cuff.shi", "sword.xun", "recover", "powerup"]
    }

    test "8/8 chat_chance_combat=100", %{world: world} do
      for key <- Map.keys(@payloads) do
        ob = npc(world, key)
        assert ob != nil, "#{key} not found"
        assert ob.meta.chat_chance_combat == 100, "#{key} chat_chance_combat"
      end
    end

    test "8/8 chat_msg_combat 逐招一致", %{world: world} do
      for {key, payload} <- @payloads do
        ob = npc(world, key)
        assert ob.meta.chat_msg_combat == payload, "#{key} chat_msg_combat"
      end
    end
  end

  # ---------- 2. 何足道 greeting ----------

  describe "何足道 greeting（LPC init/greeting，30% play jian-jia）" do
    defp hezudao_npc(combat \\ Combat.new()) do
      %Kalevala.Character{
        id: "90740dc0",
        name: "何足道",
        pid: self(),
        room_id: "kunlun:sanshengtang",
        inventory: [],
        meta: %NonPlayerMeta{
          zone_id: "clone_lib",
          aliases: ["kunlun_hezudao", "he zudao"],
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: combat
        }
      }
    end

    defp player do
      %Kalevala.Character{
        id: "player:1",
        name: "张三",
        pid: self(),
        room_id: "kunlun:sanshengtang",
        inventory: [],
        meta: %Kantele.Character.PlayerMeta{
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Combat.new()
        }
      }
    end

    test "别名派发命中：hash id 走 kunlun_hezudao 别名注册" do
      # 30% 概率门：反复调用直到命中一次即证明别名注册生效（非 :fallback）。
      result =
        Stream.repeatedly(fn -> NpcGreeting.greet(hezudao_npc(), player()) end)
        |> Enum.find(&match?({:say, _}, &1))

      assert {:say, _lines} = result, "别名未命中（恒 fallback 或恒 skip）"
    end

    test "战斗中 → :skip（LPC !is_fighting()）" do
      fighting = Combat.add_enemy(Combat.new(), %{id: "enemy:1", name: "敌人"})
      assert NpcGreeting.greet(hezudao_npc(fighting), player()) == :skip
    end

    test "30% 门统计：多次调用既有 greeting 也有 skip" do
      results =
        for _ <- 1..200 do
          NpcGreeting.greet(hezudao_npc(), player())
        end

      greetings = Enum.count(results, &match?({:say, _}, &1))
      # 30% ± 合理波动；200 次下 20~100 之间几乎不可能失败
      assert greetings > 20 and greetings < 100, "greetings=#{greetings}"
    end

    test "greeting 文案为蒹葭弹琴 vision（lvl=480 ≥ 300 最高档）" do
      # 锁 30% 门：反复取到一次 {:say, lines} 即可断言文案
      lines =
        Stream.repeatedly(fn -> NpcGreeting.greet(hezudao_npc(), player()) end)
        |> Enum.find_value(fn
          {:say, lines} -> lines
          _ -> nil
        end)

      assert [{:vision, text}] = lines
      assert text == "{npc}摆好焦尾琴弹了一首蒹葭，宛若清溪流上心头，令人无酒自醉，却又似身至仙境，心灵空明。"
    end
  end
end
