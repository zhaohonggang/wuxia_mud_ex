# 每次运行前清空数据库：上游 ExVenture 套件会写入固定用户名/邮箱，
# 上一次运行残留的行会触发 users_lower_username_index 唯一约束冲突。

# 保险丝：TRUNCATE 前先确认当前连的确实是测试库（*_test）。
# 一旦 misconfig/误设 MIX_ENV 连到 dev/生产库会直接报错，绝不误删角色存档。
current_db =
  Ecto.Adapters.SQL.query!(ExVenture.Repo, "SELECT current_database()")
  |> Map.fetch!(:rows)
  |> hd()
  |> hd()

unless String.ends_with?(current_db, "_test") do
  raise """
  拒绝清空数据库 "#{current_db}"：不是测试库（应以 _test 结尾）。
  测试只允许操作测试库，防止误删 dev/生产角色数据。
  请检查 config/test.exs 中 ExVenture.Repo 的 url（应为 postgresql://postgres:postgres@db/ex_venture_test）。
  """
end

tables =
  Ecto.Adapters.SQL.query!(
    ExVenture.Repo,
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('schema_migrations', 'schema_migrations_locks')"
  )
  |> Map.fetch!(:rows)
  |> List.flatten()

if tables != [] do
  Ecto.Adapters.SQL.query!(
    ExVenture.Repo,
    "TRUNCATE TABLE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE"
  )
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ExVenture.Repo, :manual)