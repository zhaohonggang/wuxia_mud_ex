import PropTypes from "prop-types";

let ref = null;

export const setSocket = (socket) => {
  ref = socket;
};

export const getSocket = () => ref;

export const socketRefPropType = PropTypes.shape({
  send: PropTypes.func.isRequired,
  alive: PropTypes.func.isRequired,
});
