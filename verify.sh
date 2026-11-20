set -e

# 本机（Windows / 低内存环境）跑全量测试时，BEAM 一旦遇到不可恢复错误
# （典型为 eheap_alloc 堆分配失败）会默认往当前工作目录写 erl_crash.dump；
# 该文件会把 VM 内所有进程堆 + 全部 ETS 快照序列化下来，实测可达 10-20 GB，
# 足以占满系统盘。CI / 本地回归都不需要这份 dump。
# 排障需要时，临时删掉下面这行（或 `ERL_CRASH_DUMP_BYTES=  mix test`）即可恢复。
export ERL_CRASH_DUMP_BYTES=0

mix format --check-formatted
mix compile --force --warnings-as-errors
mix credo
mix test

cd assets

yarn lint:ci
yarn test
