// Aegis Download Manager - Extension Service Worker & Stream Sniffer
// Uses Direct Local HTTP Bridge (Instant, zero-setup) and Native Messaging Host (Fallback)

const HOST_NAME = "com.aegis.downloadmanager";
const AEGIS_PORTS = [28795, 28796, 28797];

// Context menus setup
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "aegis-download-link",
    title: "Download with Aegis",
    contexts: ["link"]
  });

  chrome.contextMenus.create({
    id: "aegis-download-media",
    title: "Download Media with Aegis",
    contexts: ["image", "video", "audio"]
  });

  chrome.contextMenus.create({
    id: "aegis-download-page",
    title: "Download Page / Video with Aegis",
    contexts: ["page"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  let targetUrl = info.linkUrl || info.srcUrl || info.pageUrl;
  if (!targetUrl) return;

  sendToAegis({
    action: "download",
    url: targetUrl,
    page_url: tab ? tab.url : "",
    page_title: tab ? tab.title : ""
  });
});

// Listener for messages from DOM content script or popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request && request.action === "check-connection") {
    checkAegisConnection().then((res) => {
      sendResponse(res);
    });
    return true; // Keep message channel open for async response
  }

  if (request && request.action === "download") {
    sendToAegis(request).then((res) => {
      sendResponse(res);
    });
    return true;
  }
});

// Stream Sniffing via WebRequest
const MEDIA_EXTS = [".mp4", ".m4v", ".webm", ".m3u8", ".mpd", ".flv", ".ts", ".m4s", "videoplayback"];

if (chrome.webRequest && chrome.webRequest.onResponseStarted) {
  chrome.webRequest.onResponseStarted.addListener(
    (details) => {
      if (details.tabId < 0 || !details.url) return;
      const urlLower = details.url.toLowerCase();

      let detectedExt = "";
      for (const ext of MEDIA_EXTS) {
        if (urlLower.includes(ext)) {
          detectedExt = ext.replace(".", "");
          break;
        }
      }

      if (!detectedExt && details.responseHeaders) {
        const ctHeader = details.responseHeaders.find(h => h.name.toLowerCase() === "content-type");
        if (ctHeader && ctHeader.value) {
          const val = ctHeader.value.toLowerCase();
          if (val.includes("video/mp4")) detectedExt = "mp4";
          else if (val.includes("video/webm")) detectedExt = "webm";
          else if (val.includes("mpegurl") || val.includes("m3u8")) detectedExt = "m3u8";
          else if (val.includes("dash+xml")) detectedExt = "mpd";
        }
      }

      if (detectedExt) {
        try {
          chrome.tabs.sendMessage(details.tabId, {
            type: "AEGIS_STREAM_DETECTED",
            url: details.url,
            ext: detectedExt
          }).catch(() => {});
        } catch (e) {}
      }
    },
    { urls: ["<all_urls>"], types: ["media", "xmlhttprequest", "other"] },
    ["responseHeaders"]
  );
}

// Intercept browser download requests if enabled
if (chrome.downloads && chrome.downloads.onCreated) {
  chrome.downloads.onCreated.addListener(async (downloadItem) => {
    const settings = await chrome.storage.local.get({ interceptDownloads: false });
    if (settings.interceptDownloads && downloadItem.url && !downloadItem.url.startsWith("blob:")) {
      chrome.downloads.cancel(downloadItem.id, () => {
        sendToAegis({
          action: "download",
          url: downloadItem.url,
          filename: downloadItem.filename || "",
          referrer: downloadItem.referrer || ""
        });
      });
    }
  });
}

// Check connectivity to Aegis
async function checkAegisConnection() {
  for (const port of AEGIS_PORTS) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 1200);
      const res = await fetch(`http://127.0.0.1:${port}/ping`, {
        method: "GET",
        signal: controller.signal
      });
      clearTimeout(timeoutId);
      if (res.ok) {
        return { status: "ok", message: "Aegis Download Manager is connected and ready." };
      }
    } catch (e) {}
  }

  // Try native host check
  return new Promise((resolve) => {
    try {
      chrome.runtime.sendNativeMessage(HOST_NAME, { action: "ping" }, (response) => {
        if (chrome.runtime.lastError || !response || response.status !== "ok") {
          resolve({
            status: "error",
            error: "Aegis Download Manager is not running. Launch Aegis to enable downloads."
          });
        } else {
          resolve({ status: "ok", message: "Connected to Aegis Download Manager." });
        }
      });
    } catch (err) {
      resolve({
        status: "error",
        error: "Aegis Download Manager is not running. Launch Aegis to enable downloads."
      });
    }
  });
}

// Send download task to Aegis
async function sendToAegis(payload) {
  // 1. Direct HTTP Bridge (Instant, works out-of-the-box without host registration)
  for (const port of AEGIS_PORTS) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2000);
      const res = await fetch(`http://127.0.0.1:${port}/download`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: controller.signal
      });
      clearTimeout(timeoutId);
      if (res.ok) {
        const data = await res.json();
        return { status: "ok", message: data.message || "Sent to Aegis Download Manager" };
      }
    } catch (e) {}
  }

  // 2. Fallback to Native Messaging (can launch Aegis if closed)
  return new Promise((resolve) => {
    try {
      chrome.runtime.sendNativeMessage(HOST_NAME, payload, (response) => {
        if (chrome.runtime.lastError) {
          resolve({
            status: "error",
            error: "Aegis is not running. Please open Aegis Download Manager."
          });
        } else if (response && response.status === "error") {
          resolve({
            status: "error",
            error: response.error || response.message || "Aegis rejected task"
          });
        } else {
          resolve({ status: "ok", message: "Sent to Aegis Download Manager" });
        }
      });
    } catch (err) {
      resolve({
        status: "error",
        error: "Aegis is not running. Please open Aegis Download Manager."
      });
    }
  });
}
