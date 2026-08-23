import { Creators } from "./redux";

export class Socket {
  constructor(path) {
    this.path = path;
    this.queue = [];
    this.loginReplay = [];
    this.loginCaptured = 0;
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

      this.connecting = false;
      this.startPing();

      // 重连成功：先自动重放 登录名/密码/角色名，
      // 再补发离线期间键入的命令（顺序不能颠倒）
      let queue = this.queue;
      this.queue = [];

      if (this.loginReplay.length > 0) {
        setTimeout(() => this.replayLogin(), 200);
      }

      queue.forEach((event, i) => {
        setTimeout(() => this.rawSend(event), 500 + i * 250);
      });

      if (this.onOpen) {
        this.onOpen(e);
      }
    };

    this.socket.onclose = (e) => {
      console.log("Socket closed");
      clearInterval(this.pingTimeout);

      if (this.onClose) {
        this.onClose(e);
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
      this.captureLogin(event);
      this.socket.send(JSON.stringify(event));
      return;
    }

    // 离线：缓存输入
    if (this.socket == undefined || this.socket.readyState == WebSocket.CLOSED) {
      this.captureLogin(event);
      this.queue.push(event);
      this.reconnect();
    } else {
      // CONNECTING：等 onopen 后统一冲刷
      this.captureLogin(event);
      this.queue.push(event);
    }
  }

  captureLogin(event) {
    // 每条连接的前三条文本输入即 登录名/密码/角色名
    if (
      this.loginCaptured < 3 &&
      event &&
      event.topic == "system/send" &&
      this.loginReplay.length < 3
    ) {
      this.loginReplay.push(event);
      this.loginCaptured += 1;
    }
  }

  replayLogin() {
    console.log("Replaying login sequence");

    this.loginReplay.forEach((event, i) => {
      setTimeout(() => {
        this.rawSend(event);
      }, i * 300);
    });
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
