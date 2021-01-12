import { timeAgo, calcDuration, formatBytes } from "./formatting.js";

const LOGS_ORIGIN = "https://honeyshell-logs.tunshell.com";
const FILES_PER_SESSION = 9;

export default class Recordings {
  constructor(modal) {
    console.log("init recordings...");
    this.modal = modal;
    this.root = document.querySelector("main");
    this.loading = this.root.querySelector(".loading");
    this.recordingsList = this.root.querySelector(".recordings");
    this.loadMore = this.root.querySelector("button.load-more");

    this.continuationToken = "";
    this.recordings = [];
    this.recordingsBuff = [];

    this.loadNext(10).then(() => this.hideLoading());

    this.loadMore.addEventListener("click", () => this.loadNext(10));
    this.recordingsList.addEventListener("click", (e) =>
      this.handleRecordingClick(e)
    );
  }

  async loadNext(num) {
    console.log(`fetching ${num} recordings...`);

    this.loadMore.setAttribute("disabled", "disabled");
    const recordings = await this.fetchRecordings(num);

    this.recordings = this.recordings.concat(recordings);

    if (this.recordingsBuff.length > 0 || recordings.length === num) {
      this.loadMore.removeAttribute("disabled");
    }

    this.appendRecordings(recordings);
  }

  showLoading() {
    this.loading.style.display = "";
  }

  hideLoading() {
    this.loading.style.display = "none";
  }

  async fetchRecordings(num) {
    const amountNeeded = Math.max(0, num - this.recordingsBuff.length);
    let recs = this.recordingsBuff.splice(
      0,
      Math.min(this.recordingsBuff.length - 1, num)
    );

    if (amountNeeded > 0) {
      const results = await fetch(
        `${LOGS_ORIGIN}/?list-type=2&max-keys=${
          num * FILES_PER_SESSION
        }&cb=${Date.now()}${
          this.continuationToken &&
          `&continuation-token=${this.continuationToken}`
        }`
      ).then((r) => r.text());

      const parser = new DOMParser();
      const doc = parser.parseFromString(results, "text/xml");

      this.continuationToken =
        (doc.querySelector("NextContinuationToken") || {}).textContent || "";

      const items = Array.from(doc.querySelectorAll("Contents")).map((i) => {
        const obj = {};
        for (const node of i.children) {
          obj[node.tagName] = node.textContent;
        }

        return obj;
      });

      let recordings = {};

      for (const item of items) {
        const recordingKey = item.Key.split("/")[0];

        if (!recordings[recordingKey]) {
          recordings[recordingKey] = {};
        }

        const recording = recordings[recordingKey];

        if (item.Key.endsWith("manifest.json")) {
          recording.manifestUrl = `${LOGS_ORIGIN}/${item.Key}`;
        }

        if (item.Key.endsWith("ttyout")) {
          recording.authenticated = true;
          recording.ttyoutUrl = `${LOGS_ORIGIN}/${item.Key}`;
          recording.ttyoutSize = item.Size;
        }

        for (const file of [
          "timing",
          "log.json",
          "stdin",
          "stdout",
          "stderr",
        ]) {
          if (item.Key.endsWith(file)) {
            recording[
              file.replace(/(\..*$)/g, "") + "Url"
            ] = `${LOGS_ORIGIN}/${item.Key}`;
          }
        }
      }

      recordings = Object.values(recordings);
      recordings = recordings.filter((i) => i.authenticated);
      recordings = recordings.filter((i) => !!i.manifestUrl);

      recs = recs.concat(recordings.slice(0, amountNeeded));
      this.recordingsBuff = this.recordingsBuff.concat(
        recordings.slice(amountNeeded + 1)
      );
    }

    // Load manifests in parallel
    await Promise.all(
      recs.map(async (r) => {
        try {
          r.manifest = await fetch(r.manifestUrl).then((r) => r.json());
        } catch (e) {
          console.log("failed to load manifest for recording", r, e);
        }
      })
    );

    return recs;
  }

  renderRecordings() {
    this.recordingsList.innerHTML = "";
    this.appendRecordings(this.recordings);
  }

  appendRecordings(recordings) {
    let dom = "";

    for (const recording of recordings) {
      const ip =
        recording.manifest.ip_info && recording.manifest.ip_info.country
          ? recording.manifest.ip_info
          : "";

      const data = recording.manifest;

      dom += `<li>
            <div class="main-info">
                ${
                  ip &&
                  `<img src="https://www.countryflags.io/${ip.country}/flat/32.png" />`
                }
                <span class="ip">${data.peer_ip}</span>
                ${
                  ip &&
                  `
                <span class="loc">
                    <span class="loc">${ip.city}, ${ip.country}</span>
                </span>
                `
                }
                <span class="time-ago">${timeAgo(
                  new Date(data.time_start)
                )} ago</span>
            </div>
            <div class="supplementary-info">
                <span class="duration">duration: ${calcDuration(
                  new Date(data.time_start),
                  new Date(data.time_end)
                )}</span>
                ${ip && `<span class="org">org: ${ip.org}</span>`}
                <span class="port">src port: ${data.peer_port}</span>
                ${
                  (recording.ttyoutSize || "") &&
                  `<span class="ttySize">tty (gz): ${formatBytes(
                    recording.ttyoutSize
                  )}</span>`
                }
            </div>
        </li>`;
    }

    this.recordingsList.innerHTML += dom;
  }

  handleRecordingClick(e) {
    const recording = e.target.closest(".recordings > li");

    if (!recording) {
      return;
    }

    const index = Array.from(this.recordingsList.children).indexOf(recording);

    if (index === -1) {
      return;
    }

    this.modal.show(this.recordings[index]);
  }
}
