import Recordings from "./recordings.js";
import Modal from "./modal.js";

const init = () => {
  console.log("init");
  const modal = new Modal();
  new Recordings(modal);
};

init();
