defmodule Kantele.World.XingxiuFlatterTest do
  @moduledoc """
  星宿派 #812 丁春秋 flatter 两步拜师定向测试。

  LPC 依据：`kungfu/class/xingxiu/ding.c:141-200` 与 `xingxiu.h welcome()`。
  覆盖：数字门后置 pending、重复 attempt 拒绝、flatter 文案双条件、
  成功 recruit / 失败拒绝 / 无参数 / 无 pending 放行。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.FamilyEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Loader
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.NpcActions.XingxiuFlatter
  alias Kantele.World.Room

  @room_id "xiyu:riyuedong"
  @npc_name "丁春秋"
  @pending_key "pending/flatter"

  defp apprentice do
    %{
      family: "星宿派",
      permit_recruit: true,
      no_min_shen: true,
      max_shen: -12_000,
      max_shen_deny: "老仙我越看你越象白道派来卧底的。",
      min_exp: 300_000,
      min_exp_deny: "你这点微末道行如何能学到老仙的神妙功夫。",
      min_skills: %{"chousui-zhang" => 120, "poison" => 120},
      min_skills_deny: %{
        "chousui-zhang" => "你抽髓掌都没熟练，居然还有脸来见我？",
        "poison" => "你毒技都没学明白，还有脸来见我？"
      },
      accept_msg: "这还差不多。",
      pending_recruit: "flatter",
      pending_recruit_msg: "我星宿老仙比起古往今来的圣人怎么样啊？",
      pending_recruit_emote: "星宿老怪微闭双眼，手捻长须，一副等人拍马(flatter)的样子。",
      pending_recruit_deny: "你如此不把老仙放在眼里，老仙怎会收你？",
      pending_recruit_fail: "你如此不把我放在眼里，我怎能收你？",
      pending_recruit_no_arg: "你说老仙什么？"
    }
  end

  defp stats(overrides \\ %{}) do
    Map.merge(
      %Stats{
        shen: -13_000,
        combat_exp: 400_000,
        skills: %{"chousui-zhang" => 130, "poison" => 130}
      },
      overrides
    )
  end

  defp player(opts \\ []) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player:test"),
      name: Keyword.get(opts, :name, "李四"),
      pid: self(),
      room_id: @room_id,
      meta: %PlayerMeta{
        stats: Keyword.get(opts, :stats, stats()),
        vitals: %Vitals{
          qi: 150,
          max_qi: 150,
          jing: 150,
          max_jing: 150,
          neili: 150,
          max_neili: 150
        },
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  defp npc(opts \\ []) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "npc:xingxiu_ding"),
      name: Keyword.get(opts, :name, @npc_name),
      room_id: @room_id,
      meta: %NonPlayerMeta{
        aliases: ["xingxiu_ding", "ding chunqiu", "ding"],
        teach: %{family: "星宿派"},
        apprentice: apprentice()
      },
      pid: self()
    }
  end

  defp handler_conn(opts \\ []) do
    %Conn{
      character: player(opts),
      private: %Conn.Private{
        room: %Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(opts \\ []) do
    %{
      verb: "flatter",
      trailing: Keyword.get(opts, :trailing, ""),
      room_id: Keyword.get(opts, :room_id, @room_id),
      npc: Keyword.get(opts, :npc, npc())
    }
  end

  defp recruit_data(overrides \\ %{}) do
    %{
      ok: true,
      family: "星宿派",
      master_id: "npc:xingxiu_ding",
      master_name: @npc_name,
      student_name: "李四",
      teach: %{family: "星宿派"},
      apprentice: apprentice()
    }
    |> Map.merge(overrides)
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> data
      _ -> ""
    end)
    |> Enum.join("")
  end

  defp vision_text(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join("")
  end

  defp updated(conn), do: conn.private.update_character || conn.character

  describe "注册与 UCL 数据" do
    test "xiyu:riyuedong 的 flatter 已注册到 XingxiuFlatter" do
      assert {:ok, {XingxiuFlatter, :run}} = NpcActionHandlers.lookup(@room_id, "flatter")
    end

    test "其它房间未注册 flatter，不抢同名动词" do
      assert {:unimplemented, "flatter"} = NpcActionHandlers.lookup("city:kedian", "flatter")
    end

    test "丁春秋 UCL apprentice 段已落完整 pending_recruit 配置" do
      ding = Enum.find(Loader.load().characters, &(&1.name == @npc_name))
      assert ding != nil
      cfg = ding.meta.apprentice
      assert cfg.pending_recruit == "flatter"
      assert cfg.pending_recruit_msg == "我星宿老仙比起古往今来的圣人怎么样啊？"
      assert cfg.pending_recruit_emote =~ "等人拍马(flatter)"
      assert cfg.pending_recruit_deny == "你如此不把老仙放在眼里，老仙怎会收你？"
      assert cfg.pending_recruit_fail == "你如此不把我放在眼里，我怎能收你？"
      assert cfg.pending_recruit_no_arg == "你说老仙什么？"
    end
  end

  describe "attempt_apprentice 后半段（FamilyEvent 延迟收徒）" do
    test "数字门通过后落 pending/flatter 并播提示+vision，不立即入门派" do
      conn = build_conn(player())
      result = FamilyEvent.result(conn, %Event{topic: "family/result", data: recruit_data()})

      assert PlayerMeta.get_temp(updated(result).meta, @pending_key) == 1
      assert updated(result).meta.family == nil
      assert vision_text(result) =~ "#{@npc_name}说道：我星宿老仙比起古往今来的圣人怎么样啊？"
      assert vision_text(result) =~ "星宿老怪微闭双眼，手捻长须，一副等人拍马(flatter)的样子。"
      refute output_text(result) =~ "这还差不多"
    end

    test "pending 未 flatter 又拜师 → 只播「不把老仙放在眼里」拒绝" do
      conn = build_conn(player(temp: %{@pending_key => 1}))
      result = FamilyEvent.result(conn, %Event{topic: "family/result", data: recruit_data()})

      assert updated(result).meta.family == nil
      assert vision_text(result) =~ "#{@npc_name}说道：你如此不把老仙放在眼里，老仙怎会收你？"
    end

    test "数字门不过时仍走原拒绝路径，不落 pending" do
      conn = build_conn(player(stats: stats(%{shen: 0})))
      result = FamilyEvent.result(conn, %Event{topic: "family/result", data: recruit_data()})

      assert PlayerMeta.get_temp(updated(result).meta, @pending_key) == nil
      assert output_text(result) =~ "老仙我越看你越象白道派来卧底的"
    end
  end

  describe "flatter handler（LPC do_flatter）" do
    test "无 pending → :not_handled，不播文案" do
      assert :not_handled = XingxiuFlatter.run(handler_conn(), params())
    end

    test "别的房间 / 别的 NPC → :not_handled" do
      assert :not_handled = XingxiuFlatter.run(handler_conn(), params(room_id: "city:kedian"))

      assert :not_handled =
               XingxiuFlatter.run(
                 handler_conn(),
                 params(npc: npc(name: "洪教主", id: "npc:hong"))
               )
    end

    test "无参数 → notify_fail，pending 保留" do
      conn = handler_conn(temp: %{@pending_key => 1})
      result = XingxiuFlatter.run(conn, params(trailing: ""))

      assert output_text(result) == "你说老仙什么？"
      assert PlayerMeta.get_temp(updated(result).meta, @pending_key) == 1
    end

    test "只含称号不含颂词 → 清 pending、广播骂词、不入门派" do
      conn = handler_conn(temp: %{@pending_key => 1})
      result = XingxiuFlatter.run(conn, params(trailing: "星宿老仙，你好厉害"))

      assert PlayerMeta.get_temp(updated(result).meta, @pending_key) == nil
      assert updated(result).meta.family == nil
      assert vision_text(result) =~ "{npc}大声说道：星宿老仙，你好厉害"
      assert vision_text(result) =~ "#{@npc_name}说道：你如此不把我放在眼里，我怎能收你？"
    end

    test "只含颂词不含称号 → 同样拒绝" do
      conn = handler_conn(temp: %{@pending_key => 1})
      result = XingxiuFlatter.run(conn, params(trailing: "德配天地，威震寰宇"))

      assert updated(result).meta.family == nil
      assert vision_text(result) =~ "#{@npc_name}说道：你如此不把我放在眼里，我怎能收你？"
    end

    test "称号 + 任一颂词 → smile + say + recruit，pending 不残留" do
      for praise <- ["德配天地", "威震寰宇", "古今无比"] do
        conn = handler_conn(temp: %{@pending_key => 1})
        result = XingxiuFlatter.run(conn, params(trailing: "星宿老仙，#{praise}！"))

        enrolled = updated(result)
        assert PlayerMeta.get_temp(enrolled.meta, @pending_key) == nil
        assert enrolled.meta.family.name == "星宿派"
        assert enrolled.meta.family.master_name == @npc_name
        assert vision_text(result) =~ "{npc}大声说道：星宿老仙，#{praise}！"
        assert vision_text(result) =~ "#{@npc_name}愉快地微笑着。"
        assert vision_text(result) =~ "#{@npc_name}说道：这还差不多。"
        # 成功台词只由 NPC 广播一次，FamilyEvent 不再私发一遍。
        refute output_text(result) =~ "这还差不多"
      end
    end
  end
end
