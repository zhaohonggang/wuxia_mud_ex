defmodule Kantele.Combat.Skills.Performs.Force.Xun do
  @moduledoc """
  exert「xun」（source force/xun.c）

  巫师调试运功：需 `can_perform/wiz_test` 与 `quest/id`（两处为同一文案）；
  按 `quest/id` 反查目标，查不到提示「没有找到这个人物。」；
  目标无所在环境提示「这个人不知道在那里耶。」；
  目标 `place` 为「西域」或「很远的地方」时传送回 `/d/foshan/street3`；
  最后输出 `%s(%s)现在在%s(%s).\\n`。不消耗资源、不忙乱。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Xun`（`skills/force_xun.ex`）的
    `Performs.Simple` spec，本文件为并存的对齐副本（仅供文案对齐）；
  - 本引擎无 `find_player` / `find_living` / `find_object` 式的跨进程对象反查，
    故 `find_quest_target/1` 恒返回「没有找到这个人物。」；后续
    「这个人不知道在那里耶。」与位置输出路径当前不可达，仅保留文案与结构，
    待接入世界对象表后再打通。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView


  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_can_perform(character),
         :ok <- check_quest_id(character),
         {:ok, target} <- find_quest_target(character),
         {:ok, where} <- check_where(target) do
      apply_effect(conn, character, target, where)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! me->query("can_perform/wiz_test"))
  #        return notify_fail("你所学的内功中没有这种功能。\n");
  defp check_can_perform(character) do
    if Map.get(character.meta.temp, :wiz_test) == true do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  # LPC: if (! me->query("quest/id"))
  #        return notify_fail("你所学的内功中没有这种功能。\n");
  defp check_quest_id(character) do
    if Map.get(character.meta.temp, :quest_id) != nil do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  # LPC: target = find_player(me->query("quest/id"));
  #      if (! target) target = find_living(me->query("quest/id"));
  #      if (! target) target = find_object(me->query("quest/id"));
  #      if (! target) return notify_fail("没有找到这个人物。\n");
  # 本引擎无跨进程对象反查原语，故恒判未找到（见 moduledoc 差异说明）。
  defp find_quest_target(_character) do
    {:error, "没有找到这个人物。\n"}
  end

  # LPC: where = environment(target);
  #      if (! where) return notify_fail("这个人不知道在那里耶。\n");
  defp check_where(nil), do: {:error, "这个人不知道在那里耶。\n"}
  defp check_where(where), do: {:ok, where}

  defp apply_effect(conn, character, target, where) do
    target = relocate_remote(target)

    # LPC: write(sprintf("%s(%s)现在在%s(%s).\n",
    #            (string)target->name(1), (string)target->query("id"),
    #            (string)where->short(), (string)file_name(where)));
    text =
      describe_location(
        Map.get(target, :name),
        Map.get(target, :id),
        Map.get(where, :short),
        Map.get(where, :file)
      )

    conn
    |> render(CommandView, "text", %{text: text})
    |> assign(:prompt, false)
    |> put_character(character)
  end

  # LPC: if (target->query("place") && (target->query("place") == "西域"
  #                                    || target->query("place") == "很远的地方"))
  #        target->move("/d/foshan/street3");
  defp relocate_remote(target) do
    if remote_place?(Map.get(target, :place)) do
      # 远端目标在 LPC 中被传送回佛山；本引擎不做跨角色传送，仅记录目标房间。
      Map.put(target, :room, "/d/foshan/street3")
    else
      target
    end
  end

  defp remote_place?(place), do: place in ["西域", "很远的地方"]

  # LPC: sprintf("%s(%s)现在在%s(%s).\n", ...) —— 逐段替换 4 个 %s。
  defp describe_location(name, id, short, file) do
    "%s(%s)现在在%s(%s).\n"
    |> String.replace("%s", to_string(name), global: false)
    |> String.replace("%s", to_string(id), global: false)
    |> String.replace("%s", to_string(short), global: false)
    |> String.replace("%s", to_string(file), global: false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // xun.c
  # 
  # int exert(object me, object target)
  # {
  #         object where;
  # 
  #         if (! me->query("can_perform/wiz_test"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (! me->query("quest/id"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         target = find_player(me->query("quest/id"));
  # 
  #         if (! target)
  #                 target = find_living(me->query("quest/id"));
  # 
  #         if (! target)
  #                 target = find_object(me->query("quest/id"));
  # 
  #         if (! target)
  #                 return notify_fail("没有找到这个人物。\n");
  # 
  #         where = environment(target);
  # 
  #         if (! where)
  #                 return notify_fail("这个人不知道在那里耶。\n");
  # 
  #         if (target->query("place")
  #            && (target->query("place") == "西域"
  #            || target->query("place") == "很远的地方"))
  #                 target->move("/d/foshan/street3");
  # 
  #         write(sprintf("%s(%s)现在在%s(%s).\n",
  #                 (string)target->name(1),
  #                 (string)target->query("id"),
  #                 (string)where->short(),
  #                 (string)file_name(where)));
  #         
  #         return 1;
  # }
end
