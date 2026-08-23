import PropTypes from "prop-types";
import React from "react";
import { connect } from "react-redux";

import { Tooltip } from "../kalevala";

import { getEventsCharacter, getEventsVitals } from "../redux";

let Vitals = ({ character, vitals }) => {
  if (vitals == null) {
    return null;
  }

  const { qi, max_qi } = vitals;
  const { jing, max_jing } = vitals;
  const { neili, max_neili } = vitals;

  const qiWidth = (qi / max_qi) * 100;
  const jingWidth = (jing / max_jing) * 100;
  const neiliWidth = (neili / max_neili) * 100;

  return (
    <div className="flex flex-col">
      <h3 className="text-xl text-gray-200 px-4 pt-4">{character.name}</h3>
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
    </div>
  );
};

Vitals.propTypes = {
  character: PropTypes.object,
  vitals: PropTypes.exact({
    qi: PropTypes.number.isRequired,
    max_qi: PropTypes.number.isRequired,
    jing: PropTypes.number.isRequired,
    max_jing: PropTypes.number.isRequired,
    neili: PropTypes.number.isRequired,
    max_neili: PropTypes.number.isRequired,
  }),
};

let mapStateToProps = (state) => {
  const character = getEventsCharacter(state);
  const vitals = getEventsVitals(state);
  return { character, vitals };
};

export default connect(mapStateToProps)(Vitals);
