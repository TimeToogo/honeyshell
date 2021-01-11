import { timeAgo, calcDuration, formatBytes } from "./formatting.js";

export default class Modal {
  constructor() {
    console.log("init modal...");
    this.root = document.querySelector(".modal");
    this.term = this.root.querySelector(".xterm");
    this.info = this.root.querySelector(".info");
    this.close = this.root.querySelector(".close");

    this.hide();

    this.close.addEventListener("click", () => this.hide());
  }

  hide() {
    this.root.style.display = "none";
    this.reset();
  }

  reset() {
    if (this.xterm) {
      this.xterm.dispose();
      this.xterm = null;
    }

    const oldTerm = this.term;
    this.term = document.createElement("div");
    this.term.innerHTML = '<div class="mount"></div>';
    this.term.classList.add("xterm");
    oldTerm.parentElement.replaceChild(this.term, oldTerm);

    this.info.innerHTML = "";
  }

  async show(recording) {
    this.root.style.display = "";
    this.xterm = new Terminal();
    this.fitAddon = new FitAddon.FitAddon();
    this.xterm.loadAddon(this.fitAddon);
    this.xterm.open(this.term.querySelector(".mount"));
    this.fitAddon.fit();

    this.renderInfo(recording);

    if (!recording.ttyout) {
      const ttyData = await Promise.all([
        this.loadTtyout(recording),
        this.loadTimings(recording),
      ]);

      recording.ttyout = ttyData[0];
      recording.timings = ttyData[1];
    }

    // @see https://opensource.apple.com/source/sudo/sudo-66/src/sudoreplay.c.auto.html parse_timing for format
    if (recording.timings) {
      let i = 0;
      for (const timing of recording.timings) {
        console.log(timing);
        const sleep = Number(timing[1]);
        const bytes = Number(timing[2]);

        await new Promise((r) => setTimeout(r, sleep * 1000));
        await new Promise((r) =>
          this.xterm.write(recording.ttyout.slice(i, i + bytes), r)
        );
        i += bytes;
      }
    } else {
      this.xterm.write(recording.ttyout);
    }
  }

  loadTtyout(recording) {
    console.log("fetching tty out", recording.ttyoutUrl);
    return fetch(recording.ttyoutUrl)
      .then((r) => r.arrayBuffer())
      .then((buff) => pako.inflate(buff));
  }

  loadTimings(recording) {
    if (!recording.timingUrl) {
      return null;
    }

    console.log("fetching tty timings", recording.timingUrl);
    return fetch(recording.timingUrl)
      .then((r) => r.arrayBuffer())
      .then((buff) => pako.inflate(buff, { to: "string" }))
      .then((data) =>
        data
          .split("\n")
          .map((i) => i.split(" "))
          .filter((i) => i.length === 3)
      );
  }

  renderInfo(recording) {
    this.info.innerHTML = `
      <span><em>src:</em> ${recording.manifest.peer_ip}:${recording.manifest.peer_port}</span>
      <span><em>location:</em> ${recording.manifest.ip_info.city}, ${recording.manifest.ip_info.country}</span>
      <span><em>org:</em> ${recording.manifest.ip_info.org}</span>
      <span><em>start time:</em> ${recording.manifest.time_start}</span>
      <span><em>end time:</em> ${recording.manifest.time_end}</span>
    `;
  }
}
