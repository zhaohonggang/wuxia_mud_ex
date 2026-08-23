defmodule WsHandshake do
  # 手工 WebSocket 升级握手验证（验证 101 Switching Protocols）
  def run() do
    {:ok, sock} =
      :gen_tcp.connect(~c"127.0.0.1", 4000, [:binary, packet: :raw, active: false, buffer: 65_536])

    key = Base.encode64(:crypto.strong_rand_bytes(16))

    request =
      "GET /socket HTTP/1.1\r\n" <>
        "Host: localhost:4000\r\n" <>
        "Upgrade: websocket\r\n" <>
        "Connection: Upgrade\r\n" <>
        "Sec-WebSocket-Key: #{key}\r\n" <>
        "Sec-WebSocket-Version: 13\r\n\r\n"

    :ok = :gen_tcp.send(sock, request)

    case :gen_tcp.recv(sock, 0, 5000) do
      {:ok, data} ->
        [status | _rest] = String.split(data, "\r\n")
        IO.puts("HANDSHAKE: #{status}")

      other ->
        IO.puts("RECV #{inspect(other)}")
    end

    # 保持连接 70 秒验证超过默认 60s idle 不被踢
    Process.sleep(1000)

    case :gen_tcp.recv(sock, 0, 65_000) do
      {:ok, data} -> IO.puts("STILL CONNECTED after wait (got #{byte_size(data)}B)")
      {:error, :closed} -> IO.puts("CONNECTION CLOSED during idle wait")
      {:error, other} -> IO.puts("ERR #{inspect(other)}")
    end

    :gen_tcp.close(sock)
  end
end

WsHandshake.run()
