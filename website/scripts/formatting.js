export const timeAgo = (time) => {
  if (isNaN(time.getTime())) {
    return "unknown";
  }

  let units = [
    { name: "second", limit: 60, in_seconds: 1 },
    { name: "minute", limit: 3600, in_seconds: 60 },
    { name: "hour", limit: 86400, in_seconds: 3600 },
    { name: "day", limit: 604800, in_seconds: 86400 },
    { name: "week", limit: 2629743, in_seconds: 604800 },
    { name: "month", limit: 31556926, in_seconds: 2629743 },
    { name: "year", limit: null, in_seconds: 31556926 },
  ];
  let diff = (new Date() - time) / 1000;
  if (diff < 5) return "now";

  let i = 0;
  let unit;
  while ((unit = units[i++])) {
    if (diff < unit.limit || !unit.limit) {
      diff = Math.floor(diff / unit.in_seconds);
      return diff + " " + unit.name + (diff > 1 ? "s" : "");
    }
  }
};

export const calcDuration = (start, end) => {
  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    return "unknown";
  }

  const diffSecs = Math.round((end - start) / 1000);

  if (diffSecs < 60) {
    return diffSecs + " sec";
  } else {
    return Math.round(diffSecs / 60) + " min";
  }
};

export const formatBytes = (bytes) => {
  if (bytes < 1024) {
    return bytes + " bytes";
  }

  if (bytes < Math.pow(1024, 2)) {
    return Math.round(bytes / 1024) + " KB";
  }

  return Math.round(bytes / Math.pow(1024, 2)) + " MB";
};
