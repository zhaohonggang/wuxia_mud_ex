#!/bin/sh
# Phase-A smoke: aliases, exercise, jiali, shop
printf 'grant\r\n'
sleep 4
printf 'x\r\n'
sleep 2
printf 'grant\r\n'
sleep 6
# A8: 中文方向别名 + 看别名 + 回来
printf '北\r\n'
sleep 3
printf '南\r\n'
sleep 3
# A9: jiali 档位
printf 'jiali 5\r\n'
sleep 3
printf 'jiali 999\r\n'
sleep 3
# A6: 打坐(小耗气量)
printf 'exercise 20\r\n'
sleep 30
printf 'world_status\r\n'
sleep 5
printf 'quit\r\n'
sleep 2
