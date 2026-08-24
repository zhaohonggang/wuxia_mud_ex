import { Creators } from "./redux";

export class Socket {
  constructor(path) {
    this.path = path;
    this.queue = [];
    this.reconnecting = false;
  }

  connect() {
    const protocol = location.protocol == "https:" ? "wss:" : "ws:";

    this.connecting = true;
    this.socket = new WebSocket(`${protocol}//${location.host}${this.path}`);

    this.socket.onmessage = (message) => {
      let event = JSON.parse(message.data);
      if (this.onEvent) {
        this.onEvent(event);
      }
    };

    this.socket.onopen = (e) => {
      console.log("Socket opened");
      clearInterval(this.pingTimeout);
      this.startPing();

      // 重连后需要手动重新登录（标准 MUD 行为）
      // 不做自动重放，避免游戏命令被误当登录信息

      if (this.onOpen) {
        this.onOpen(e);
      }
    };

    this.manualClose = false;
    this.retryDelay = 1000;

    this.socket.onclose = (e) => {
      console.log("Socket closed");
      clearInterval(this.pingTimeout);

      if (this.onClose) {
        this.onClose(e);
      }

      // 断线后自动重连（1s 起步指数退避，封顶 10s；连接成功后归零）
      if (!this.manualClose) {
        let delay = Math.min((this.retryDelay || 1000) * 2, 10_000);
        this.retryDelay = delay;
        console.log(`Reconnecting in ${delay}ms`);
        setTimeout(() => {
          this.reconnecting = false;
          this.connect();
        }, delay);
      }
    };

    this.socket.onerror = (e) => {
      console.log("Socket error");

      if (this.onError) {
        this.onError(e);
      }
    };
  }

  startPing() {
    clearInterval(this.pingTimeout);
    this.pingTimeout = setInterval(() => {
      this.rawSend({ topic: "system/ping" });
    }, 5000);
  }

  // 断线时调用 send 会先入队并触发重连；
  // 重连成功后队列自动冲刷，随后自动重放登录序列
  send(event) {
    if (this.socket && this.socket.readyState == WebSocket.OPEN) {

      this.socket.send(JSON.stringify(event));
      return;
    }

    // 离线：缓存输入
    if (this.socket == undefined || this.socket.readyState == WebSocket.CLOSED) {

      this.queue.push(event);
      this.reconnect();
    } else {
      // CONNECTING：等 onopen 后统一冲刷

      this.queue.push(event);
    }
  }




  rawSend(event) {
    this.socket.send(JSON.stringify(event));
  }

  reconnect() {
    if (this.reconnecting || this.alive()) {
      return;
    }

    this.reconnecting = true;
    console.log("Reconnecting...");
    this.connect();
    this.reconnecting = false;
  }

  alive() {
    return this.socket && this.socket.readyState == WebSocket.OPEN;
  }

  onEvent(fun) {
    this.onEvent = fun;
  }

  onOpen(fun) {
    this.onOpen = fun;
  }

  onClose(fun) {
    this.onClose = fun;
  }

  onError(fun) {
    this.onError = fun;
  }
}

export const makeReduxSocket = (path, store, eventHandlerArguments = {}) => {
  const socket = new Socket(path);

  return new ReduxSocket(socket, {
    connected: (socket) => {
      store.dispatch(Creators.socketConnected(socket));
    },
    disconnected: () => {
      store.dispatch(Creators.socketDisconnected());
    },
    receivedEvent: (event) => {
      store.dispatch(Creators.socketReceivedEvent(event, eventHandlerArguments));
    },
  });
};

export class ReduxSocket {
  constructor(socket, creators) {
    this.socket = socket;
    this.creators = creators;
  }

  join() {
    this.socket.connect();
    this.connect();
  }

  connect() {
    this.socket.onEvent((event) => {
      this.creators.receivedEvent(event);
    });

    this.socket.onOpen(() => {
      this.creators.connected(this);
    });

    this.socket.onClose(() => {
      this.creators.disconnected();
    });

    this.socket.onError(() => {
      this.creators.disconnected();
    });
  }

  send(event) {
    this.socket.send(event);
  }
}
