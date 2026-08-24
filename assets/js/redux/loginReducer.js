import { createReducer } from "../kalevala";

import { Types } from "./actions";

const INITIAL_STATE = {
  active: false,
  atPrompt: false,
  loggedIn: false,
};

const loginActive = (state) => {
  return { ...state, active: true };
};

const loginPrompt = (state) => {
  return { ...state, atPrompt: true };
};

const loggedIn = (state) => {
  return { ...state, loggedIn: true };
};

const worldEntered = (state) => {
  return { ...state, atPrompt: false, loggedIn: true };
};

const HANDLERS = {
  [Types.LOGIN_ACTIVE]: loginActive,
  [Types.LOGIN_PROMPT]: loginPrompt,
  [Types.LOGGED_IN]: loggedIn,
  [Types.WORLD_ENTERED]: worldEntered,
};

export const loginReducer = createReducer(INITIAL_STATE, HANDLERS);
