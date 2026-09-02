defmodule Kantele.CommandProbeTest do
  @moduledoc """
  命令占位桩探测测试（P0 基座验证）

  断言：除显式白名单（后续批次尚未迁移的命令）外，不应出现新的占位桩。
  """

  use ExUnit.Case, async: false

  alias Kantele.CommandProbe

  @whitelist %{
    # M1
    "purchase_command" => "M1",
    # M2
    "assist_command" => "M2",
    "steal_command" => "M2",
    "hit_command" => "M2",
    "guard_command" => "M2",
    # M3
    "talk_command" => "M3",
    "to_command" => "M3",
    "touch_command" => "M3",
    # M4
    "secularize_command" => "M4",
    "special_command" => "M4",
    "stab_command" => "M4",
    "stay_command" => "M4",
    "stop_command" => "M4",
    "train_command" => "M4",
    "vote_command" => "M4",
    # S1-S4 社会系统
    # K1-K3 skill 家族
    # 后续批次
    "cut_command" => "后续批次",
    "hand_command" => "后续批次",
    "push_command" => "后续批次",
    "release_command" => "后续批次",
    "come_command" => "后续批次",
    "delayed_command" => "后续批次",
    "reload_command" => "后续批次",
    "remove_command" => "后续批次",
    "respirate_command" => "后续批次",
    "beep_command" => "后续批次",
    "bjtime_command" => "后续批次",
    "close_command" => "后续批次",
    "closed_command" => "后续批次",
    "cls_command" => "后续批次",
    "color_command" => "后续批次",
    "describe_command" => "后续批次",
    "detach_command" => "后续批次",
    "drink_command" => "后续批次",
    "emote_command" => "后续批次",
    "enable_command" => "后续批次",
    "exercise_command" => "后续批次",
    "fight_command" => "后续批次",
    "fill_command" => "后续批次",
    "flee_command" => "后续批次",
    "follow_command" => "后续批次",
    "give_command" => "后续批次",
    "jiali_command" => "后续批次",
    "learn_command" => "后续批次",
    "liuxi_command" => "后续批次",
    "map_command" => "后续批次",
    "move_command" => "后续批次",
    "nick_command" => "后续批次",
    "note_command" => "后续批次",
    "open_command" => "后续批次",
    "pai_commands" => "后续批次",
    "perform_command" => "后续批次",
    "pkd_command" => "后续批次",
    "prepare_command" => "后续批次",
    "recall_command" => "后续批次",
    "ride_command" => "后续批次",
    "score2_command" => "后续批次",
    "score_command" => "后续批次",
    "suicide_command" => "后续批次",
    "surrender_command" => "后续批次",
    "title_command" => "后续批次",
    "top_command" => "后续批次",
    "top2_command" => "后续批次",
    "topp_command" => "后续批次",
    "tune_command" => "后续批次",
    "unride_command" => "后续批次",
    "whistle_command" => "后续批次",
    "wield_command" => "后续批次",
    "wimpy_command" => "后续批次",
    "world_status_command" => "后续批次",
    "version_command" => "后续批次",
    "whisper_command" => "后续批次",
    "who_command" => "后续批次",
    "tell_command" => "后续批次",
    "time_command" => "后续批次",
    "tianshu_command" => "后续批次",
    "jifen_command" => "后续批次",
    "scheme_command" => "后续批次",
    "abandon_command" => "后续批次",
    "answer_command" => "后续批次",
    "ansuan_command" => "M3",
    "beg_command" => "后续批次",
    "quest_command" => "后续批次",
    "quest_ask_command" => "后续批次",
    "bank_command" => "后续批次",
    "hp_command" => "后续批次",
    "info_command" => "后续批次",
    "look_command" => "后续批次",
    "save_command" => "后续批次",
    "quit_command" => "后续批次",
    "set_command" => "后续批次",
    "passwd_command" => "后续批次",
    "id_command" => "后续批次",
    "alias_command" => "后续批次",
    "option_command" => "后续批次",
    "finger_command" => "后续批次",
    "backpack_command" => "后续批次",
    "daub_command" => "后续批次",
    "sell_command" => "后续批次",
    "skills_command" => "后续批次",
    "study_command" => "后续批次",
    "team_command" => "后续批次",
    "help_command" => "后续批次",
    "commands_command" => "后续批次"
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
end
