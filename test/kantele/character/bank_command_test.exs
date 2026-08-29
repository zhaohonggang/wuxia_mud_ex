defmodule Kantele.Character.BankCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BankCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: 0
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  # 命令经 put_character 把更新后的角色写入 conn.private.update_character
  defp updated_meta(conn), do: (conn.private.update_character || conn.character).meta

  test "裸 bank 查出空余额" do
    # 命令分发以 (conn, params) 双参调用 :show，这里直接走该入口防 arity 崩
    conn = BankCommand.show(build_conn(player()), %{})
    assert output_text(conn) =~ "共存了一文钱"
    assert output_text(conn) =~ "身上带着一文钱"
  end

  test "run 无参兜底也走查余额" do
    conn = BankCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "共存了一文钱"
  end

  test "存款：5 两白银入库，身上铜钱减少" do
    p = %{player() | meta: %{player().meta | coins: 500}}
    conn = BankCommand.run(build_conn(p), %{"rest" => "deposit 5 silver"})

    assert output_text(conn) =~ "你存入了五两白银"
    assert output_text(conn) =~ "户头里现在有五两白银"
    assert updated_meta(conn).bank_coins == 500
    assert updated_meta(conn).coins == 0
  end

  test "存款不够时拒绝" do
    p = %{player() | meta: %{player().meta | coins: 100}}
    conn = BankCommand.run(build_conn(p), %{"rest" => "存 5 银"})

    assert output_text(conn) =~ "你身上带的白银不够"
    # 状态不变
    assert updated_meta(conn).bank_coins == nil
    assert updated_meta(conn).coins == 100
  end

  test "取款：从钱庄取出，身上铜钱增加" do
    p = %{player() | meta: PlayerMeta.put_bank_coins(%{player().meta | coins: 0}, 500)}
    conn = BankCommand.run(build_conn(p), %{"rest" => "withdraw 5 silver"})

    assert output_text(conn) =~ "你取出了五两白银"
    assert output_text(conn) =~ "户头里还剩一文钱"
    assert updated_meta(conn).bank_coins == 0
    assert updated_meta(conn).coins == 500
  end

  test "取款超余款时拒绝" do
    p = %{player() | meta: PlayerMeta.put_bank_coins(%{player().meta | coins: 0}, 100)}
    conn = BankCommand.run(build_conn(p), %{"rest" => "withdraw 2 silver"})

    assert output_text(conn) =~ "你存的钱不够取"
  end

  test "未知货币拒绝" do
    conn = BankCommand.run(build_conn(player()), %{"rest" => "deposit 5 翡翠"})
    assert output_text(conn) =~ "没有这种货币"
  end

  test "bank/银行 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("bank")
    assert parsed.module == Kantele.Character.BankCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("银行")
    assert parsed.module == Kantele.Character.BankCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("bank deposit 5 silver")
    assert parsed.module == Kantele.Character.BankCommand
  end
end
