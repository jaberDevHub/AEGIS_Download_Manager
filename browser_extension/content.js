// Aegis Download Manager - DOM Stream Sniffer & Video Overlay
// Injects floating 'Download Video' panel on YouTube and HTML5 video players

(function() {
    'use strict';

    if (window.__aegis_sniffer_injected) return;
    window.__aegis_sniffer_injected = true;

    let detectedStreams = [];
    let activePanel = null;
    let isDropdownOpen = false;
    let lastKnownUrl = window.location.href;

    const SHIELD_SVG = `
        <svg class="aegis-shield-icon" viewBox="0 0 24 24">
            <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 2.18l7 3.12v4.7c0 4.54-3.04 8.79-7 9.94-3.96-1.15-7-5.4-7-9.94V6.3l7-3.12z"/>
        </svg>
    `;

    function isYouTube() {
        return window.location.hostname.includes('youtube.com') || 
               window.location.hostname.includes('youtu.be') || 
               Boolean(document.querySelector('#movie_player, .html5-video-player'));
    }

    function getPageVideoTitle() {
        if (isYouTube()) {
            const ytTitle = document.querySelector('h1.ytd-watch-metadata yt-formatted-string, #title h1, h1.title, yt-formatted-string');
            if (ytTitle && ytTitle.textContent.trim()) {
                return ytTitle.textContent.trim();
            }
        }
        return document.title.replace(/ - YouTube$/, '').trim() || 'video_stream';
    }

    function findVideoContainer() {
        const ytPlayer = document.querySelector('#movie_player, .html5-video-player, #player-container');
        if (ytPlayer) return ytPlayer;

        const videoEl = document.querySelector('video');
        if (videoEl) {
            return videoEl.parentElement || videoEl;
        }
        return null;
    }

    function createSnifferPanel(container) {
        if (document.getElementById('aegis-video-sniffer-panel')) {
            return;
        }

        const panel = document.createElement('div');
        panel.id = 'aegis-video-sniffer-panel';

        // Main trigger button
        const btn = document.createElement('button');
        btn.className = 'aegis-main-trigger-btn';
        btn.innerHTML = `${SHIELD_SVG}<span>Download Video</span><span class="aegis-stream-count-badge" id="aegis-badge">HD</span>`;
        btn.onclick = (e) => {
            e.stopPropagation();
            toggleDropdown();
        };

        // Quality dropdown menu
        const dropdown = document.createElement('div');
        dropdown.className = 'aegis-quality-dropdown';
        dropdown.id = 'aegis-dropdown-menu';

        panel.appendChild(btn);
        panel.appendChild(dropdown);

        // Ensure container is positioned relatively so panel floats correctly
        const computedStyle = window.getComputedStyle(container);
        if (computedStyle.position === 'static') {
            container.style.position = 'relative';
        }

        container.appendChild(panel);
        activePanel = panel;

        populateQualities();

        // Close dropdown when clicking outside
        document.addEventListener('click', (e) => {
            if (!panel.contains(e.target)) {
                closeDropdown();
            }
        });
    }

    function toggleDropdown() {
        const dd = document.getElementById('aegis-dropdown-menu');
        if (!dd) return;
        isDropdownOpen = !isDropdownOpen;
        if (isDropdownOpen) {
            populateQualities();
            dd.classList.add('aegis-open');
        } else {
            dd.classList.remove('aegis-open');
        }
    }

    function closeDropdown() {
        const dd = document.getElementById('aegis-dropdown-menu');
        if (dd) {
            dd.classList.remove('aegis-open');
            isDropdownOpen = false;
        }
    }

    function populateQualities() {
        const dd = document.getElementById('aegis-dropdown-menu');
        if (!dd) return;

        dd.innerHTML = `
            <div class="aegis-dropdown-header">
                <span>Aegis Stream Sniffer</span>
                <span>Select Quality</span>
            </div>
        `;

        const options = [];

        if (isYouTube()) {
            options.push(
                { label: 'Best Available (4K / 1080p)', badge: 'MAX', formatId: 'bestvideo+bestaudio/best', audioOnly: false },
                { label: '1080p Full HD', badge: '1080p', formatId: 'bestvideo[height<=1080]+bestaudio/best', audioOnly: false },
                { label: '720p HD', badge: '720p', formatId: 'bestvideo[height<=720]+bestaudio/best', audioOnly: false },
                { label: '480p Standard', badge: '480p', formatId: 'bestvideo[height<=480]+bestaudio/best', audioOnly: false },
                { label: 'Audio Only (MP3)', badge: 'AUDIO', formatId: 'bestaudio/best', audioOnly: true }
            );
        } else {
            options.push(
                { label: 'Original Video Stream', badge: 'AUTO', formatId: 'auto', audioOnly: false },
                { label: 'Audio Extract (MP3)', badge: 'AUDIO', formatId: 'audio', audioOnly: true }
            );
        }

        // Add any sniffed direct streams detected from network traffic
        detectedStreams.forEach((st, idx) => {
            options.push({
                label: `Sniffed Stream #${idx + 1} (${st.ext ? st.ext.toUpperCase() : 'MEDIA'})`,
                badge: st.ext ? st.ext.toUpperCase() : 'STREAM',
                formatId: 'direct',
                directUrl: st.url
            });
        });

        options.forEach(opt => {
            const item = document.createElement('div');
            item.className = 'aegis-quality-option';
            item.innerHTML = `
                <div class="aegis-opt-left">
                    <span class="aegis-opt-badge ${opt.audioOnly ? 'audio' : ''}">${opt.badge}</span>
                    <span>${opt.label}</span>
                </div>
                <span class="aegis-opt-size">Download</span>
            `;
            item.onclick = (e) => {
                e.stopPropagation();
                triggerDownload(opt);
            };
            dd.appendChild(item);
        });
    }

    function triggerDownload(opt) {
        closeDropdown();

        const videoUrl = opt.directUrl || window.location.href;
        const pageTitle = getPageVideoTitle();
        const fname = opt.audioOnly ? `${pageTitle}.mp3` : `${pageTitle}.mp4`;

        const payload = {
            action: 'download',
            url: videoUrl,
            filename: fname,
            format_id: opt.formatId || '',
            audio_only: Boolean(opt.audioOnly),
            page_url: window.location.href,
            page_title: pageTitle
        };

        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
            chrome.runtime.sendMessage(payload, (res) => {
                const runtimeError = chrome.runtime.lastError;
                const error = runtimeError && runtimeError.message || res && res.error;
                if (error || !res || res.status !== 'ok') {
                    showToast(getConnectionError(error));
                    return;
                }
                showToast('Sent to Aegis Download Manager!');
            });
        } else {
            showToast('Aegis browser extension is not connected.');
        }
    }

    function getConnectionError(message) {
        const error = String(message || '');
        if (/not running|could not connect|connection failed|failed to fetch/i.test(error)) {
            return 'Aegis is not running. Please open Aegis Download Manager.';
        }
        return error || 'Aegis is not running. Please open Aegis Download Manager.';
    }

    function showToast(msg) {
        if (!activePanel) return;
        const existing = activePanel.querySelector('.aegis-success-toast');
        if (existing) existing.remove();

        const toast = document.createElement('div');
        toast.className = 'aegis-success-toast';
        toast.textContent = msg;
        activePanel.appendChild(toast);

        setTimeout(() => {
            toast.remove();
        }, 3000);
    }

    // Receiver for sniffed stream events from background script
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
        chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
            if (msg.type === 'AEGIS_STREAM_DETECTED' && msg.url) {
                if (!detectedStreams.some(s => s.url === msg.url)) {
                    detectedStreams.push(msg);
                    const badge = document.getElementById('aegis-badge');
                    if (badge) {
                        badge.textContent = `${detectedStreams.length}`;
                    }
                }
            }
        });
    }

    // Attach sniffer panel to video elements
    function checkAndAttach() {
        const currentUrl = window.location.href;
        if (currentUrl !== lastKnownUrl) {
            lastKnownUrl = currentUrl;
            detectedStreams = [];
            const existingPanel = document.getElementById('aegis-video-sniffer-panel');
            if (existingPanel) {
                existingPanel.remove();
                activePanel = null;
            }
        }

        const container = findVideoContainer();
        if (container && !document.getElementById('aegis-video-sniffer-panel')) {
            createSnifferPanel(container);
        }
    }

    // YouTube SPA & history navigation listeners
    window.addEventListener('yt-navigate-finish', () => {
        setTimeout(checkAndAttach, 400);
    });
    window.addEventListener('popstate', () => {
        setTimeout(checkAndAttach, 400);
    });

    const observer = new MutationObserver(() => {
        checkAndAttach();
    });

    observer.observe(document.documentElement, {
        childList: true,
        subtree: true
    });

    // Periodic check to ensure panel attaches reliably
    checkAndAttach();
    setInterval(checkAndAttach, 1200);

})();
