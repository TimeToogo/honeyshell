import { timeAgo, calcDuration, formatBytes } from "./formatting.js";
import Recordings from "./recordings.js";

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
    this.xterm = new Terminal({});
    this.xterm.open(this.term.querySelector(".mount"));

    this.renderInfo(recording);

    if (!recording.logs) {
      recording.logs = await this.loadLogs(recording);
    }

    this.xterm.resize(
      Number(recording.logs.columns),
      Number(recording.logs.lines)
    );

    if (this.isLoginShell(recording)) {
      if (!recording.ttyout) {
        console.log("Loading tty data...");
        const data = await Promise.all([
          this.loadTtyout(recording),
          this.loadTimings(recording),
        ]);

        recording.ttyout = data[0];
        recording.timings = data[1];
      }

      await this.replayTty(recording);
    } else {
      if (!recording.stdout) {
        console.log("Loading stdout/stderr...");
        const data = await Promise.all([
          this.loadStdout(recording),
          this.loadStderr(recording),
        ]);

        recording.stdout = data[0];
        recording.stderr = data[1];
      }

      await this.replayInitialCommand(recording);
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

  loadLogs(recording) {
    if (!recording.logUrl) {
      return null;
    }

    return fetch(recording.logUrl).then((r) => r.json());
  }

  loadStdout(recording) {
    if (!recording.stdoutUrl) {
      return null;
    }

    return fetch(recording.stdoutUrl)
      .then((r) => r.arrayBuffer())
      .then((buff) => pako.inflate(buff));
  }

  loadStderr(recording) {
    if (!recording.stderrUrl) {
      return null;
    }

    return fetch(recording.stderrUrl)
      .then((r) => r.arrayBuffer())
      .then((buff) => pako.inflate(buff));
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

  isLoginShell(recording) {
    if (!recording.logs && recording.runargv) {
      return true;
    }

    return recording.logs.runargv.join(" ") === "/bin/bash -l";
  }

  async replayInitialCommand(recording) {
    await this.writeToTerm(recording.logs.runargv.join(" ") + "\r\n");
    await this.writeToTerm("\r\nstdout:\r\n")
    await this.writeToTerm(recording.stdout);
    await this.writeToTerm("\r\nstderr:\r\n")
    await this.writeToTerm(recording.stderr);
  }

  async replayTty(recording) {
    // @see https://opensource.apple.com/source/sudo/sudo-66/src/sudoreplay.c.auto.html parse_timing for format
    if (recording.timings) {
      let i = 0;
      for (const timing of recording.timings) {
        const sleep = Number(timing[1]);
        const bytes = Number(timing[2]);

        await new Promise((r) => setTimeout(r, sleep * 1000));
        await this.writeToTerm(recording.ttyout.slice(i, i + bytes));
        i += bytes;
      }
    } else {
      await this.writeToTerm(recording.ttyout);
    }
  }

  async writeToTerm(data) {
    await new Promise((r) => this.xterm.write(data, r));
  }
}
