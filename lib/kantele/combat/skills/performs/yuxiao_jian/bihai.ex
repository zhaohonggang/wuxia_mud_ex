defmodule Kantele.Combat.Skills.Performs.YuxiaoJian.Bihai do
  @moduledoc """
  perform「碧海潮生按玉箫」（source yuxiao-jian/bihai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"ap", "yuxiao-jian"}, {"dp", "force"}, {"skill", "yuxiao-jian"}], "level_gates": [{"bibo-shengong", "180"}, {"bihai-chaosheng", "180"}], "map_gates": [{"sword", "yuxiao-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"skill", "180"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你手里没有拿萧，难以施展", "你玉箫剑法等级不够, 难以施展", "你碧波神功修为不够，难以施展", "你的碧海潮生曲太低，难以施展", "你没有激发玉箫剑法，难以施展", "你现在的内力不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("yuxiao-jian", 1) +
      #                me->query_skill("bibo-shengong", 1) +
      #                me->query_skill("chuixiao-jifa")", "dp_formula": "target->query_skill("force") +
      #                target->query_skill("parry") +
      #                target->query_skill("chuixiao-jifa") / 2"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n只见$N" HIW "手按玉箫，脚踏八卦四方之位，奏出"
      #                 "一曲「碧海潮生按玉箫」。便听得那箫声如鸣琴击玉，轻轻"
      #                 "发了几声，接着悠悠扬扬，飘下清亮柔和的洞箫声来。\n" NOR", "= HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
      #                          "裕如。\n" NOR", "= HIW "\n突然又听那洞箫声情致飘忽，缠绵宛转，便似一个女"
      #                  "子一会儿叹息，一会儿又似呻吟，一会儿却又软语温存或柔"
      #                  "声叫唤。\n" NOR", "= HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
      #                          "裕如。\n" NOR", "= HIW "\n那箫声清亮宛如大海浩淼，万里无波，远处潮水缓缓"
      #                  "推近，渐近渐快，其后洪涛汹涌，白浪连山，而潮水中鱼跃"
      #                  "鲸浮，海面风啸鸥飞，水妖海怪群魔弄潮，极尽变幻之能事"
      #                  "。\n" NOR", "= HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
      #                          "裕如。\n" NOR", "= HIW "\n时至最后，却听那箫声愈来愈细，几乎难以听闻，便"
      #                  "尤如大海潮退后水平如镜一般，但海底却又是暗流湍急，汹"
      #                  "涌澎湃。\n" NOR", "= HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
      #                          "裕如。\n" NOR"], "success": ["= HIR "$n" HIR "只感心头一震，脸上情不自禁的露"
      #                          "出了一丝微笑。\n" NOR", "= HIR "$n" HIR "只感全身热血沸腾，就只想手舞足"
      #                          "蹈的乱动一番。\n" NOR", "= HIR "霎时间$n" HIR "只感心头滚热，喉干舌燥，"
      #                          "说不出的难受。\n" NOR", "= HIR "此时$n" HIR "已身陷绝境，全身气血逆流，"
      #                          "再也无法脱身。\n" NOR"]}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage * 2 / 3", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
