import React from "react";
import { combineReducers, compose, createStore } from "redux";

import {
  Creators as KalevalaCreators,
  Types as KalevalaTypes,
  kalevalaMiddleware,
  promptReducer,
  socketReducer,
} from "./kalevala";

import { Creators, channelReducer, eventsReducer, loginReducer } from "./redux";

const composeEnhancers =
  typeof window === "object" && window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__
    ? window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__({})
    : compose;

// Convert Kalevala {color ...} tags to React elements with inline styles
const parseColorTags = (text) => {
  // First split text by tags, keeping track of positions
  const tokens = [];
  let lastIndex = 0;
  const regex = /(?:\{color\s+[^}]+\}|\{\/color\})/g;
  let match;

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      tokens.push({ type: "text", content: text.slice(lastIndex, match.index) });
    }
    if (match[0].startsWith("{color")) {
      const attrStr = match[0].slice(7, -1); // remove "{color " and "}"
      const attrs = {};
      attrStr.replace(/(?:\w+)="(?:[^"]*)"/g, (_, key, value) => {
        attrs[key] = value;
      });
      tokens.push({ type: "open", attrs });
    } else {
      tokens.push({ type: "close" });
    }
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    tokens.push({ type: "text", content: text.slice(lastIndex) });
  }

  // Build React elements with style stack
  const elements = [];
  const styleStack = [];

  for (const token of tokens) {
    if (token.type === "text") {
      const style = styleStack.length > 0 ? { color: styleStack[styleStack.length - 1].foreground } : null;
      if (style) {
        elements.push(React.createElement("span", { key: Math.random(), style }, token.content));
      } else {
        elements.push(token.content);
      }
    } else if (token.type === "open") {
      styleStack.push(token.attrs);
    } else if (token.type === "close") {
      styleStack.pop();
    }
  }

  return elements.length === 1 ? elements[0] : React.createElement("span", null, ...elements);
};

const dispatchEventText = (dispatch, getState, event, { history }) => {
  const { data, text, topic } = event;

  dispatch(
    KalevalaCreators.socketReceivedEvent(
      {
        topic: KalevalaTypes.SOCKET_RECEIVED_EVENT,
        data: { event: { topic, data } },
      },
      { history },
    ),
  );

  dispatch(
    KalevalaCreators.socketReceivedEvent(
      {
        topic: "system/display",
        data: text,
      },
      { history },
    ),
  );
};

const eventTextHandlers = {
  "Channel.Broadcast": (dispatch, getState, event, { history }) => {
    const { channel_name, character, id, text } = event.data;
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: "\n" }, { history }));
    dispatch(Creators.channelBroadcast(channel_name, character, id, parseColorTags(text)));
  },
  "Character.Info": dispatchEventText,
  "Character.Detail": dispatchEventText,
  "Commands.Index": dispatchEventText,
  "Character.Prompt": (dispatch, getState, event, { history }) => {
    const { text } = event;
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
  },
  "Inventory.All": dispatchEventText,
  "Inventory.DropItem": dispatchEventText,
  "Inventory.PickupItem": dispatchEventText,
  "Character.Score": dispatchEventText,
  "Shop.List": dispatchEventText,
  "Zone.MiniMap": dispatchEventText,
  "Login.Welcome": (dispatch) => {
    dispatch(Creators.loginActive());
    dispatch(Creators.loginPrompt());
  },
  "Login.PromptCharacter": (dispatch, getState, event, { history }) => {
    history.push("/login/character");
  },
  "Login.EnterWorld": (dispatch, getState, event, { history }) => {
    const { data, text } = event;

    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
    dispatch(Creators.loggedIn(data.character));
    dispatch(Creators.worldEntered());

    history.push("/play");
  },
  "Room.CharacterEnter": (dispatch, getState, event, { history }) => {
    const { data, text } = event;
    dispatch(Creators.roomCharacterEntered(data.character));
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
  },
  "Room.CharacterLeave": (dispatch, getState, event, { history }) => {
    const { data, text } = event;
    dispatch(Creators.roomCharacterLeft(data.character));
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
  },
  "Room.Info": (dispatch, getState, event, { history }) => {
    const { text } = event;
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
  },
  "Room.Info.Extra": (dispatch, getState, event, { history }) => {
    const { text } = event;
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
  },
  "Room.Say": (dispatch, getState, event, { history }) => {
    const { text } = event;
    dispatch(KalevalaCreators.socketReceivedEvent({ topic: "system/display", data: text }, { history }));
  },
};

const systemEventHandlers = {
  "system/event-text": (dispatch, getState, event, args) => {
    const { topic, data } = event.data;

    let handler = eventTextHandlers[topic];

    if (handler) {
      handler(dispatch, getState, event.data, args);
    }

    dispatch(KalevalaCreators.socketReceivedEvent({ topic, data }, args));
  },
};

const middleware = compose(kalevalaMiddleware(systemEventHandlers), composeEnhancers());

const reducers = combineReducers({
  channel: channelReducer,
  login: loginReducer,
  prompt: promptReducer,
  socket: socketReducer,
  events: eventsReducer,
});

export const makeStore = () => {
  return createStore(reducers, middleware);
};
