defmodule Kantele.Character.ToCommand do
  @moduledoc """
  to命令：`to <verb> [target]`

  对应 LPC cmds/std/to.c
  多行信息发布。进入多行编辑状态，输入消息，以单独一行 `.` 结束。

  支持的 verb（与 LPC valid_verb 对应）：

  - tell / reply / say：标准命令，需对象（tell）或不需（reply/say）
  - chat / wiz / debug / sys / rumor / sing / party / shout：频道命令
  - describe：用户命令，无消耗，不加空格，长度受限

  消耗：按最终消息长度 × 10 扣除 neili，不足则扣 jing，两者都不足则拒绝。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Controllers.ToEditorController

  # LPC valid_verb 标志（对应 to.c 第 18-32 行）
  @verbs %{
    "tell" => %{need_opp: true, append_cr: true, std: true},
    "reply" => %{need_opp: false, append_cr: true, std: true},
    "say" => %{need_opp: false, append_cr: true, std: true},
    "chat" => %{need_opp: false, append_cr: true, std: false},
    "wiz" => %{need_opp: false, append_cr: true, std: false},
    "debug" => %{need_opp: false, append_cr: true, std: false},
    "sys" => %{need_opp: false, append_cr: true, std: false},
    "rumor" => %{need_opp: false, append_cr: true, std: false},
    "sing" => %{need_opp: false, append_cr: true, std: false},
    "party" => %{need_opp: false, append_cr: true, std: false},
    "shout" => %{need_opp: false, append_cr: true, std: false},
    "describe" => %{need_opp: false, append_cr: false, std: false, usr: true,
                   no_cost: true, no_space: true, limit_long: true}
  }

  @doc """
  处理 `to` 命令入口。

  - `%{}`：裸 `to`，显示帮助格式
  - `%{"rest" => rest}`：`to <rest>`，解析 verb 和 target 后进入多行编辑
  """
  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest)

    case String.split(rest, " ", parts: 2) do
      [verb] ->
        handle_verb(conn, verb, nil)

      [verb, target] ->
        handle_verb(conn, verb, String.trim(target))

      [] ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：to say | tell | chat | rumor ... [sb]\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, params) do
    cond do
      map_size(params) == 0 ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：to say | tell | chat | rumor ... [sb]\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        # Should not reach here - all non-empty params should have :rest key
        conn
        |> render(CommandView, "text", %{text: "指令格式：to say | tell | chat | rumor ... [sb]\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp handle_verb(conn, verb, target) do
    case Map.fetch(@verbs, verb) do
      {:ok, flags} ->
        cond do
          flags[:need_opp] and is_nil(target) ->
            conn
            |> render(CommandView, "text", %{text: "你必须指明对象才能发出信息。\n"})
            |> prompt(CommandView, "prompt", %{})

          true ->
            enter_editor(conn, verb, target, flags)
        end

      :error ->
        conn
        |> render(CommandView, "text", %{text: "对不起，不能使用这种方式发布信息。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp enter_editor(conn, verb, target, flags) do
    editor_state = %{
      verb: verb,
      target: target,
      flags: flags,
      lines: []
    }

    conn
    |> put_private(:to_editor, editor_state)
    |> put_controller(ToEditorController)
    |> assign(:prompt, false)
    |> render(CommandView, "text",
      %{text: "请输入#{verb}#{if target, do: "（对象：" <> target <> "）", else: ""}内容，单独一行输入 . 结束：\n"})
  end

  # Conn 模块中 put_private 是私有函数，此处直接操作 struct
  defp put_private(conn, key, value) do
    %{conn | private: Map.put(conn.private, key, value)}
  end
end
