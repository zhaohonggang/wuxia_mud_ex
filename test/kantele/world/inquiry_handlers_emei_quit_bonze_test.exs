defmodule Kantele.World.InquiryHandlers.EmeiQuitBonzeTest do
  @moduledoc """
  #857 灭绝师太「还俗」pending/quit_bonze 状态门定向测试。

  镜像 LPC `kungfu/class/emei/miejue.c` `ask_for_quit/0`：
  - 门控：非峨嵋派 → family_deny；未出家（class != bonze）→ not_bonze_deny
  - 成功：设置 pending/quit_bonze + NPC say "哼" + 私发还俗文本

  覆盖：
  - 非峨嵋派玩家 → family_deny
  - 峨嵋派但非 bonze（俗家） → not_bonze_deny
  - 峨嵋派 bonze → 成功，pending/quit_bonze 设置，npc_say 广播，私发文本
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.EmeiQuitBonze

  defp base_config do
    %{
      "kind" => "emei_quit_bonze",
      "npc_say" => "哼"
    }
  end

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "峨嵋派", class: "bonze"})
    env = Keyword.get(opts, :env, %{"gender" => "女性"})

    meta = %PlayerMeta{
      vitals: %Vitals{qi: 80, max_qi: 100},
      stats: %Stats{combat_exp: 2_000_000, shen: 0, skills: %{}},
      family: family,
      env: env,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "emei:jinding",
        attributes: %{"age" => 14},
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "emei_miejue",
      npc_name: "灭绝师太",
      npc_room_id: Keyword.get(opts, :npc_room_id, "emei:jinding")
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> data
      %Conn.EventText{text: %Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  defp channel_texts(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  describe "门控：非峨嵋派" do
    test "family != 峨嵋派 → family_deny" do
      conn0 = conn(family: %{name: "少林派", class: "bonze"})
      result = EmeiQuitBonze.run(conn0, base_config(), data())

      assert output_text(result) =~ "你是什么人？跑到这里来捣乱？"
    end
  end

  describe "门控：未出家（class != bonze）" do
    test "峨嵋派俗家 → not_bonze_deny" do
      conn0 = conn(family: %{name: "峨嵋派", class: "fighter"})
      result = EmeiQuitBonze.run(conn0, base_config(), data())

      assert output_text(result) =~ "阿弥陀佛！你本是俗家人，何谈还俗？"
    end
  end

  describe "成功流程（峨嵋派 bonze）" do
    test "设置 pending/quit_bonze + npc_say + 私发文本" do
      conn0 = conn()
      result = EmeiQuitBonze.run(conn0, base_config(), data())

      # 私发：还俗文本
      assert output_text(result) =~ "你好好的给我安心修炼，以后降妖除魔，别天天满脑子不正经。"

      # NPC say：哼（广播到房间）
      assert channel_texts(result) =~ "哼"

      # pending/quit_bonze 已设置
      character = result.private.update_character || result.character
      temp = Map.get(character.meta, :temp) || %{}
      assert temp[:pending_quit_bonze] == true
    end
  end
end
