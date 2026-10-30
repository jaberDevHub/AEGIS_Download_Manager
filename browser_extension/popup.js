const statusEl = document.getElementById("status");
const badgeEl = document.getElementById("badge");
const button = document.getElementById("check");

function checkConnection() {
  button.disabled = true;
  badgeEl.className = "badge";
  badgeEl.textContent = "Checking…";
  statusEl.textContent = "Testing connection to Aegis…";

  chrome.runtime.sendMessage({ action: "check-connection" }, (result) => {
    const runtimeError = chrome.runtime.lastError;
    button.disabled = false;

    if (runtimeError || !result || result.status !== "ok") {
      badgeEl.className = "badge disconnected";
      badgeEl.textContent = "Offline";
      statusEl.textContent = result?.error || "Aegis desktop app is not running. Launch Aegis to download.";
      return;
    }

    badgeEl.className = "badge connected";
    badgeEl.textContent = "Connected";
    statusEl.textContent = "Aegis is online. Floating download panels are active on video pages.";
  });
}

button.addEventListener("click", checkConnection);
checkConnection();
