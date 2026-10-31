defmodule Kantele.Combat.SkillsGenderGateTest do
  @moduledoc """
  「无性 / 必须男性」性别门迁移（C 相位 F4 长尾）。

  这 23 个技能此前 moduledoc 都写着「本模型暂无性别字段」而把性别门列为
  未实现；实际上性别早已建模为 `meta.env[:gender]`（默认「男性」，见
  `Records.apply_to_character/2`），且已有 11 个技能（beiming-shengong /
  duanshi-xinfa / kurong-changong 等）用 `gender_of/1` 实装。本批按 LPC
  `valid_learn` 逐条保真补齐。

  对照口径：
  - `me->query("gender")` → `meta.env[:gender]`（缺字段按「男性」，与 LPC
    未设性别时的默认一致）；
  - `me->query_skill(X, 1)` → `Stats.skill(stats, X)`（**基本技能不折半**，
    对应 LPC 的第二参数 1）；
  - `me->query("couple/have_couple")` → `meta.spouse` 非空（`%{id:, name:}`）。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.LearnCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SkillsEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BahuangGong
  alias Kantele.Combat.Skills.BiboShengong
  alias Kantele.Combat.Skills.DahaiWuliang
  alias Kantele.Combat.Skills.FenxinJue
  alias Kantele.Combat.Skills.HuntianQigong
  alias Kantele.Combat.Skills.HunyuanYiqi
  alias Kantele.Combat.Skills.LiangyiShengong
  alias Kantele.Combat.Skills.NeiBagua
  alias Kantele.Combat.Skills.ShenghuoShengong
  alias Kantele.Combat.Skills.ShenghuoXinfa
  alias Kantele.Combat.Skills.SurgeForce
  alias Kantele.Combat.Skills.TianhuanShenjue
  alias Kantele.Combat.Skills.TianleiShengong
  alias Kantele.Combat.Skills.WuwangShengong
  alias Kantele.Combat.Skills.Xiaowuxiang
  alias Kantele.Combat.Skills.XiuluoYinshagong
  alias Kantele.Combat.Skills.XuanmenNeigong
  alias Kantele.Combat.Skills.XuantianWujigong
  alias Kantele.Combat.Skills.Yujiashu
  alias Kantele.Combat.Skills.YunlongShengong
  alias Kantele.Combat.Skills.ZhanshenXinjing
  alias Kantele.Combat.Skills.ZhenyueJue
  alias Kantele.Combat.Skills.ZihuiXinfa

  # {模块, 技能 id, LPC 阈值（无性 && lvl > N 拒绝）, 拒绝文案, 其余门槛已满足的技能表}
  @wu_xing [
    {BahuangGong, "bahuang-gong", 49,
     "你无根无性，阴阳不调，难以领会高深的八荒六合唯我独尊功。\n", %{"force" => 80}},
    {BiboShengong, "bibo-shengong", 49, "你无根无性，阴阳不调，难以领会高深的碧波神功。\n",
     %{"chuixiao-jifa" => 100}},
    {DahaiWuliang, "dahai-wuliang", 49, "你无根无性，阴阳不调，难以领会高深的大海无量。\n",
     %{"force" => 50}},
    {FenxinJue, "fenxin-jue", 99, "你无根无性，阴阳不调，难以领会高深的焚心诀。\n",
     %{"force" => 70}},
    {HuntianQigong, "huntian-qigong", 49, "你无根无性，阴阳不调，难以领会更高深的混天气功。\n",
     %{"force" => 30}},
    {LiangyiShengong, "liangyi-shengong", 49, "你无根无性，阴阳不调，难以领会高深的两仪神功。\n",
     %{"force" => 60}},
    {NeiBagua, "nei-bagua", 49, "你无根无性，阴阳难调，无法学习更高深的内八卦。\n",
     %{"force" => 80, "wai-bagua" => 100}},
    {ShenghuoShengong, "shenghuo-shengong", 49,
     "你无根无性，阴阳不调，难以领会高深的圣火神功。\n", %{"force" => 180}},
    {TianhuanShenjue, "tianhuan-shenjue", 99, "你无根无性，阴阳不调，难以领会高深的天寰神诀。\n",
     %{"force" => 50}},
    {TianleiShengong, "tianlei-shengong", 49, "你无根无性，阴阳不调，难以领会高深的天雷神功。\n",
     %{"force" => 70}},
    {WuwangShengong, "wuwang-shengong", 49, "你无根无性，阴阳不调，难以领会高深的无妄神功。\n",
     %{"force" => 60}},
    {Xiaowuxiang, "xiaowuxiang", 49, "你无根无性，阴阳不调，难以领会高深的小无相功。\n",
     %{"force" => 80}},
    {XiuluoYinshagong, "xiuluo-yinshagong", 49,
     "你无根无性，阴阳不调，难以领会高深的修罗阴煞功。\n", %{"force" => 60}},
    {XuanmenNeigong, "xuanmen-neigong", 29, "你无根无性，阴阳不调，难以领会高深的玄门内功。\n",
     %{"force" => 60}},
    {XuantianWujigong, "xuantian-wujigong", 19,
     "你无根无性，阴阳不调，难以领会高深的玄天无极功。\n", %{"force" => 60}},
    {YunlongShengong, "yunlong-shengong", 49, "你无根无性，阴阳不调，难以领会高深的云龙神功。\n",
     %{"force" => 30}},
    {ZhanshenXinjing, "zhanshen-xinjing", 19, "你无根无性，阴阳不调，难以领会高深的战神心经。\n",
     %{"force" => 100}},
    {ZhenyueJue, "zhenyue-jue", 99, "你无根无性，阴阳不调，难以领会高深的镇岳诀。\n",
     %{"force" => 70}},
    {ZihuiXinfa, "zihui-xinfa", 49, "你无根无性，阴阳不调，难以领会更高深的紫徽心法。\n",
     %{"force" => 20}}
  ]

  defp stats(skills), do: %{skills: skills, int: 40, str: 50, con: 40}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "「无性」门：lvl > N 拒绝（19 技能，逐条对照 LPC）" do
    test "无性且超阈值 → 按 LPC 文案拒绝" do
      for {mod, id, thr, msg, extra} <- @wu_xing do
        s = stats(Map.put(extra, id, thr + 1))

        assert mod.valid_learn(s, char("无性")) == {:error, msg},
               "#{id} 在无性 + #{thr + 1} 级时未按 LPC 拒绝"
      end
    end

    test "无性但未超阈值 → 放行（阈值边界含等号，与 LPC `> N` 一致）" do
      for {mod, id, thr, _msg, extra} <- @wu_xing do
        s = stats(Map.put(extra, id, thr))

        assert mod.valid_learn(s, char("无性")) == :ok,
               "#{id} 在无性 + #{thr} 级（未超阈值）时被误拒"
      end
    end

    test "男性 / 女性 → 不受性别门影响" do
      for {mod, id, thr, _msg, extra} <- @wu_xing,
          gender <- ["男性", "女性"] do
        s = stats(Map.put(extra, id, thr + 100))

        assert mod.valid_learn(s, char(gender)) == :ok,
               "#{id} 对#{gender}误判"
      end
    end

    test "character 缺失 env / 为 nil → 按「男性」处理（LPC 未设性别时的默认）" do
      for {mod, id, thr, _msg, extra} <- @wu_xing do
        s = stats(Map.put(extra, id, thr + 100))

        assert mod.valid_learn(s, nil) == :ok
        assert mod.valid_learn(s, %{}) == :ok
        assert mod.valid_learn(s, %{meta: %{}}) == :ok
      end
    end
  end

  describe "shenghuo-xinfa 特殊门：查的是**圣火神功**等级，不是本技能" do
    test "无性 + 圣火神功 101 级 → 拒绝" do
      s = stats(%{"force" => 10, "shenghuo-shengong" => 101})
      assert ShenghuoXinfa.valid_learn(s, char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会高深的圣火心法。\n"}
    end

    test "无性 + 圣火神功 100 级（未超）→ 放行" do
      s = stats(%{"force" => 10, "shenghuo-shengong" => 100})
      assert ShenghuoXinfa.valid_learn(s, char("无性")) == :ok
    end

    test "本技能自身等级再高也不触发（门控对象是圣火神功）" do
      s = stats(%{"force" => 10, "shenghuo-shengong" => 0, "shenghuo-xinfa" => 500})
      assert ShenghuoXinfa.valid_learn(s, char("无性")) == :ok
    end
  end

  describe "「必须男性」门（surge-force / yujiashu）" do
    test "surge-force：女性 / 无性被拒，男性放行" do
      ok = stats(%{"force" => 150})
      msg = "你不具有男性的阳刚之气，无法修习怒海狂涛。\n"

      assert SurgeForce.valid_learn(ok, char("女性")) == {:error, msg}
      assert SurgeForce.valid_learn(ok, char("无性")) == {:error, msg}
      assert SurgeForce.valid_learn(ok, char("男性")) == :ok
    end

    test "surge-force：性别门先于 force / 膂力门（LPC 顺序）" do
      # force 与 str 都不够，但性别门在最先，报的应是性别文案
      s = stats(%{"force" => 0}) |> Map.put(:str, 0)

      assert SurgeForce.valid_learn(s, char("女性")) ==
               {:error, "你不具有男性的阳刚之气，无法修习怒海狂涛。\n"}
    end

    test "surge-force：膂力不足（男性，force 够）" do
      s = stats(%{"force" => 150}) |> Map.put(:str, 44)

      assert SurgeForce.valid_learn(s, char("男性")) ==
               {:error, "你的膂力不足，难以修习怒海狂涛。\n"}
    end

    test "yujiashu：女性 / 无性被拒，男性放行" do
      ok = stats(%{"force" => 100})
      msg = "你不是男性，无法练习瑜珈术神功。\n"

      assert Yujiashu.valid_learn(ok, char("女性")) == {:error, msg}
      assert Yujiashu.valid_learn(ok, char("无性")) == {:error, msg}
      assert Yujiashu.valid_learn(ok, char("男性")) == :ok
    end

    test "yujiashu：force 门先于性别门（LPC 顺序）" do
      s = stats(%{"force" => 99})

      assert Yujiashu.valid_learn(s, char("女性")) ==
               {:error, "你的基本内功火候不够，无法学习瑜珈术！\n"}
    end
  end

  describe "hunyuan-yiqi：已婚门 + 非男性门" do
    test "已婚 → 破色戒拒绝" do
      s = stats(%{"force" => 100, "buddhism" => 300})
      c = %{meta: %{env: %{gender: "男性"}, spouse: %{id: "p1", name: "某人"}}}

      assert HunyuanYiqi.valid_learn(s, c) ==
               {:error, "你已经破了色戒，无法再学习混元一气功！\n"}
    end

    test "未婚但非男性 → 童男之体拒绝" do
      s = stats(%{"force" => 100, "buddhism" => 300})
      c = %{meta: %{env: %{gender: "女性"}, spouse: nil}}

      assert HunyuanYiqi.valid_learn(s, c) ==
               {:error, "你非童男之体，不能练习混元一气功。\n"}
    end

    test "未婚男性 + 禅宗/内功达标 → 放行" do
      s = stats(%{"force" => 100, "buddhism" => 300})
      c = %{meta: %{env: %{gender: "男性"}, spouse: %{}}}

      assert HunyuanYiqi.valid_learn(s, c) == :ok
    end

    test "spouse 为空 map / nil 均视为未婚" do
      s = stats(%{"force" => 100, "buddhism" => 300})

      assert HunyuanYiqi.valid_learn(s, %{meta: %{env: %{gender: "男性"}, spouse: %{}}}) ==
               :ok

      assert HunyuanYiqi.valid_learn(s, %{meta: %{env: %{gender: "男性"}, spouse: nil}}) ==
               :ok
    end
  end

  describe "授艺事件管线：学生 env 必须送达师父侧" do
    test "learn 命令随事件携带 student_env / student_spouse" do
      conn =
        LearnCommand.run(build_conn(student()), %{"skill" => "yujiashu", "name" => "某师父"})

      event = Enum.find(conn.events, &match?(%Event{topic: "skills/learn"}, &1))

      assert event.data.student_env == %{gender: "女性"}
      assert event.data.student_spouse == %{id: "p2", name: "某人"}
    end

    test "师父侧按学生 env 判性别门：女性学 yujiashu 被拒" do
      SkillsEvent.teach(build_conn(teacher()), %{
        topic: "skills/teach",
        data: %{
          skill: "yujiashu",
          times: 1,
          student_stats: student_stats(),
          student_vitals: Vitals.new(),
          student_env: %{gender: "女性"},
          reply_to: self()
        }
      })

      assert_receive %Event{
        topic: "skills/learn-result",
        data: %{failure_message: "你不是男性，无法练习瑜珈术神功。\n"}
      }
    end

    test "师父侧按学生 env 判性别门：男性正常授艺" do
      SkillsEvent.teach(build_conn(teacher()), %{
        topic: "skills/teach",
        data: %{
          skill: "yujiashu",
          times: 1,
          student_stats: student_stats(),
          student_vitals: Vitals.new(),
          student_env: %{gender: "男性"},
          reply_to: self()
        }
      })

      assert_receive %Event{topic: "skills/learn-result", data: %{skill: "yujiashu"}}
    end

    test "env 缺失时回落「男性」，不误伤既有流程" do
      SkillsEvent.teach(build_conn(teacher()), %{
        topic: "skills/teach",
        data: %{
          skill: "yujiashu",
          times: 1,
          student_stats: student_stats(),
          reply_to: self()
        }
      })

      assert_receive %Event{topic: "skills/learn-result", data: %{skill: "yujiashu"}}
    end
  end

  describe "已进 Skills 注册表" do
    test "23 个技能均可解析到模块" do
      for {mod, id, _thr, _msg, _extra} <- @wu_xing do
        assert Skills.get(id) == mod, "#{id} 未注册"
      end

      assert Skills.get("shenghuo-xinfa") == ShenghuoXinfa
      assert Skills.get("surge-force") == SurgeForce
      assert Skills.get("yujiashu") == Yujiashu
      assert Skills.get("hunyuan-yiqi") == HunyuanYiqi
    end
  end

  # ---- helpers ----

  defp base_character do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room"
    }
  end

  defp student_stats do
    Stats.new()
    |> Map.put(:skills, %{"yujiashu" => 5, "force" => 100})
    |> Map.put(:potential, 50)
  end

  defp student do
    base_character()
    |> Map.put(:meta, %PlayerMeta{
      vitals: Vitals.new(),
      stats: student_stats(),
      combat: Kantele.Character.Combat.new(),
      env: %{gender: "女性"},
      spouse: %{id: "p2", name: "某人"}
    })
  end

  defp teacher do
    base_character()
    |> Map.put(:name, "某师父")
    |> Map.put(:id, "npc-gender-gate")
    |> Map.put(:meta, %PlayerMeta{
      vitals: Vitals.new(),
      stats: Map.put(Stats.new(), :skills, %{"yujiashu" => 40}),
      combat: Kantele.Character.Combat.new()
    })
  end
end
