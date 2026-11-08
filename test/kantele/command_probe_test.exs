defmodule Kantele.CommandProbeTest do
  @moduledoc """
  命令占位桩探测测试（P0 基座验证）

  断言两件事：

  1. 除显式白名单外，不应出现新的占位桩；
  2. 白名单里不应留着已经真化的命令 —— 否则第 1 条对那些文件就失去了护栏。

  第 2 条要求每次「真化」一个 B1 命令时，同步把它从白名单删掉。
  """

  use ExUnit.Case, async: false

  alias Kantele.CommandProbe

  # 2026-11-08：B1 批次（push/hand/secularize/remove/top2/topp/train/come/
  # stay/stop/release/talk/ansuan/top/special/stab/touch 等）陆续真化后，原
  # 白名单里 ~90 条早已不是占位桩，只留下这份与 `CommandProbe.stubs/0` 实测
  # 结果一一对应的清单。
  @whitelist %{
    # M3
    "to_command" => "M3",
    # M4
    "vote_command" => "M4",
    # W2
    "clone_command" => "W2",
    # 后续批次
    "answer_command" => "后续批次",
    "pkd_command" => "后续批次",
    "scheme_command" => "后续批次"
  }

  test "无未列入白名单的占位桩" do
    stub_modules = CommandProbe.stubs()

    unknown_stubs =
      Enum.reject(stub_modules, fn %{file: f} ->
        Map.has_key?(@whitelist, f)
      end)

    assert unknown_stubs == [],
           "发现未列入白名单的占位桩：#{inspect(unknown_stubs)}"
  end

  test "白名单与实测占位桩严格一致（真化后必须删条目）" do
    stub_files = CommandProbe.stubs() |> Enum.map(& &1.file) |> Enum.sort()
    whitelisted = @whitelist |> Map.keys() |> Enum.sort()

    assert whitelisted == stub_files,
           """
           白名单与实测不一致，请同步 `test/kantele/command_probe_test.exs`：

             已真化但仍列在白名单：#{inspect(whitelisted -- stub_files)}
             是占位桩但漏列白名单：#{inspect(stub_files -- whitelisted)}
           """
  end
end
