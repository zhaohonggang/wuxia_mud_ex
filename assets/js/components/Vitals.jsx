import PropTypes from "prop-types";
import React from "react";
import { connect } from "react-redux";

import { Tooltip } from "../kalevala";
import { getSocketConnectionState } from "../kalevala/redux";

import { getEventsCharacter, getEventsVitals, getLogin } from "../redux";
import { getSocket } from "../socketRef";

let Vitals = ({ atPrompt, character, characters, connected, vitals, reconnect }) => {
  const name = (character && character.name) || (characters[0] && characters[0].name);

  if (name == null && vitals == null) {
    return null;
  }

  const showReconnect = name != null && (!connected || atPrompt);

  let bars = null;

  if (vitals != null) {
    const { qi, max_qi } = vitals;
    const { jing, max_jing } = vitals;
    const { neili, max_neili } = vitals;

    const qiWidth = (qi / max_qi) * 100;
    const jingWidth = (jing / max_jing) * 100;
    const neiliWidth = (neili / max_neili) * 100;

    bars = (
      <div className="p-2 w-full">
        <div className="relative my-2 rounded bg-gray-600">
          <div className="bg-red-600 rounded absolute inset-0 z-0" style={{ width: `${qiWidth}%` }} />
          <Tooltip tip="气血 (Qi)" className="w-full right">
            <span className="relative z-10 block p-2 text-white text-lg text-right">
              {qi} / {max_qi} 气血
            </span>
          </Tooltip>
        </div>
        <div className="relative my-2 rounded bg-gray-600">
          <div className="bg-blue-600 rounded absolute inset-0 z-0" style={{ width: `${jingWidth}%` }} />
          <Tooltip tip="精力 (Jing)" className="w-full right">
            <span className="relative z-10 block p-2 text-white text-lg text-right">
              {jing} / {max_jing} 精
            </span>
          </Tooltip>
        </div>
        <div className="relative my-2 rounded bg-gray-600">
          <div className="bg-purple-600 rounded absolute inset-0 z-0" style={{ width: `${neiliWidth}%` }} />
          <Tooltip tip="内力 (Neili)" className="w-full right">
            <span className="relative z-10 block p-2 text-white text-lg text-right">
              {neili} / {max_neili} 内力
            </span>
          </Tooltip>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col">
      <div className="flex items-center justify-between px-4 pt-4">
        <h3 className="text-xl text-gray-200">{name}</h3>
        {showReconnect && (
          <button
            type="button"
            className="text-sm px-2 py-1 rounded bg-red-600 text-white hover:bg-red-500"
            title="断线重连：自动用当前角色重新登录"
            onClick={() => reconnect(name)}
          >
            重连
          </button>
        )}
      </div>
      {bars}
    </div>
  );
};

Vitals.propTypes = {
  atPrompt: PropTypes.bool.isRequired,
  character: PropTypes.object,
  characters: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string.isRequired,
    }),
  ),
  connected: PropTypes.bool.isRequired,
  vitals: PropTypes.exact({
    qi: PropTypes.number.isRequired,
    max_qi: PropTypes.number.isRequired,
    jing: PropTypes.number.isRequired,
    max_jing: PropTypes.number.isRequired,
    neili: PropTypes.number.isRequired,
    max_neili: PropTypes.number.isRequired,
  }),
  reconnect: PropTypes.func.isRequired,
};

Vitals.defaultProps = {
  characters: [],
};

let mapStateToProps = (state) => {
  const character = getEventsCharacter(state);
  const vitals = getEventsVitals(state);
  const connected = getSocketConnectionState(state);
  const atPrompt = getLogin(state).atPrompt;
  return { atPrompt, character, vitals, connected };
};

let mapDispatchToProps = (dispatch) => ({
  reconnect: (name) => {
    const socket = getSocket();

    if (socket == null) {
      return;
    }

    [name, "x", name].forEach((text) => {
      socket.send({ topic: "system/send", data: { text } });
    });
  },
});

export default connect(mapStateToProps, mapDispatchToProps)(Vitals);
