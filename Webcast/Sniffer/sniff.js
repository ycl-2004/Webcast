(() => {
  "use strict";
  if (window.__webcastInstalled) return;
  window.__webcastInstalled = true;
  const generation = window.__webcastGeneration || "";
  const frameID = Math.random().toString(36).slice(2) + Date.now();
  const limit = 512 * 1024;
  const sent = new Map();
  const manifests = new Map();
  const parents = new Map();
  let latestManifest = null;
  let route = location.href;

  function normalize(raw) {
    try {
      const url = new URL(String(raw), document.baseURI);
      if (!/^https?:$/.test(url.protocol)) return null;
      url.hash = "";
      return url.href;
    } catch (_) { return null; }
  }

  function format(url, mime = "", text = "") {
    if (text.trimStart().startsWith("#EXTM3U") || /(?:mpegurl)/i.test(mime)) return "hls";
    if (/application\/dash\+xml/i.test(mime)) return "dash";
    if (/video\/mp4/i.test(mime)) return "mp4";
    const path = new URL(url).pathname;
    if (/\.m3u8$/i.test(path)) return "hls";
    if (/\.(mp4|m4v)$/i.test(path)) return "mp4";
    if (/\.mpd$/i.test(path)) return "dash";
    return null;
  }

  function post(payload) {
    try { window.webkit.messageHandlers.videoSniffer.postMessage({...payload, generation, frameID, pageURL:location.href, title:document.title}); }
    catch (_) { /* A broken bridge must never break the site's player. */ }
  }

  function report(raw, source, extra = {}) {
    const url = normalize(raw);
    if (!url || !format(url, extra.mime, extra.manifest)) return;
    const record = {...extra, url, source};
    const signature = JSON.stringify(record);
    if (sent.get(url) === signature) return;
    sent.set(url, signature);
    if (sent.size > 200) sent.delete(sent.keys().next().value);
    post(record);
  }

  function activeVideo(video) {
    const raw = video.currentSrc || video.src;
    const duration = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : undefined;
    if (normalize(raw)) {
      const cached = manifests.get(normalize(raw)) || {};
      report(raw, "video", {...cached, current:true, duration});
    } else if (String(raw).startsWith("blob:") && latestManifest) {
      // A same-frame, recent MSE request is an inference, not proof of attachment.
      const record = manifests.get(latestManifest);
      if (!record || Date.now() - record.time > 15000) return;
      report(latestManifest, "mse", {...record, current:true, inferred:true, duration});
      const master = parents.get(latestManifest);
      if (master) report(master, "mse", {...manifests.get(master), master:true, current:true, inferred:true, duration});
    }
  }

  function inspect(raw, source, mime, text = "", requestPage = location.href) {
    if (requestPage !== location.href) return;
    const url = normalize(raw);
    if (!url) return;
    const kind = format(url, mime, text);
    if (!kind) return;
    const extra = {mime};
    if (kind === "hls" && text.trimStart().startsWith("#EXTM3U")) {
      extra.manifest = "#EXTM3U"; // Only metadata crosses the bridge, never entire playlists.
      extra.master = /#EXT-X-(?:STREAM-INF|I-FRAME-STREAM-INF)/.test(text);
      if (!extra.master) extra.live = !/#EXT-X-ENDLIST/.test(text);
      extra.drm = /METHOD=SAMPLE-AES/i.test(text) || /KEYFORMAT="(?!identity")/i.test(text);
      if (/#EXT-X-MAP:/.test(text)) extra.segmentFormat = "fmp4";
      else if (/^[^#\r\n]+\.ts(?:\?[^\r\n]*)?$/m.test(text)) extra.segmentFormat = "ts";
      if (extra.master) {
        let variant = false;
        for (const line of text.split(/\r?\n/)) {
          if (line.startsWith("#EXT-X-STREAM-INF:")) { variant = true; continue; }
          if (variant && line && !line.startsWith("#")) {
            try { parents.set(new URL(line.trim(), url).href, url); } catch (_) {}
            variant = false;
          }
        }
      }
      manifests.set(url, {...extra, time:Date.now()});
      latestManifest = url;
      if (manifests.size > 100) manifests.delete(manifests.keys().next().value);
    } else if (kind === "dash") {
      extra.drm = /<ContentProtection[\s>]/i.test(text);
    }
    report(url, source, extra);
    document.querySelectorAll("video").forEach(video => { if (!video.paused) activeVideo(video); });
  }

  // Native HLS requests bypass fetch/XHR, so observe both property setters and DOM mutations.
  function hookSrc(proto) {
    const descriptor = Object.getOwnPropertyDescriptor(proto, "src");
    if (!descriptor || !descriptor.set || !descriptor.get || !descriptor.configurable) return;
    Object.defineProperty(proto, "src", {...descriptor, set(value) {
      descriptor.set.call(this, value);
      report(this.src, this.tagName === "SOURCE" ? "source" : "video", {current:this.tagName === "VIDEO", mime:this.type || ""});
    }});
  }
  hookSrc(HTMLMediaElement.prototype);
  hookSrc(HTMLSourceElement.prototype);
  const originalAttribute = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function(name, value) {
    const result = originalAttribute.apply(this, arguments);
    if (String(name).toLowerCase() === "src" && /^(VIDEO|SOURCE)$/.test(this.tagName)) {
      report(this.src, this.tagName.toLowerCase(), {current:this.tagName === "VIDEO", mime:this.type || ""});
    }
    return result;
  };
  function scan() {
    document.querySelectorAll("video, video source").forEach(element => {
      report(element.currentSrc || element.src, element.tagName.toLowerCase(), {mime:element.type || ""});
    });
  }
  let queued = false;
  new MutationObserver(() => {
    if (queued) return;
    queued = true;
    queueMicrotask(() => { queued = false; scan(); });
  }).observe(document, {subtree:true, childList:true, attributes:true, attributeFilter:["src"]});
  for (const event of ["play", "playing", "loadedmetadata", "durationchange"]) {
    document.addEventListener(event, e => { if (e.target.tagName === "VIDEO") activeVideo(e.target); }, true);
  }
  document.addEventListener("DOMContentLoaded", scan);
  scan();

  if (window.fetch) {
    const originalFetch = window.fetch;
    window.fetch = function() {
      const requestPage = location.href;
      return originalFetch.apply(this, arguments).then(response => {
        const mime = response.headers.get("content-type") || "";
        const url = response.url;
        inspect(url, "fetch", mime, "", requestPage);
        // Do not clone/read binary MP4/TS responses or unbounded live streams.
        const likelyText = /mpegurl|dash\+xml|(?:text|json)|octet-stream/i.test(mime)
          || /\.(m3u8|mpd)(?:\?|$)/i.test(url);
        const length = Number(response.headers.get("content-length"));
        if (likelyText && (!length || length <= limit) && response.body) {
          (async () => {
            const reader = response.clone().body.getReader();
            const decoder = new TextDecoder();
            let content = "", size = 0;
            try {
              for (;;) {
                const {done, value} = await reader.read();
                if (done) break;
                size += value.byteLength;
                if (size > limit) { await reader.cancel(); return; }
                content += decoder.decode(value, {stream:true});
              }
              content += decoder.decode();
              inspect(url, "fetch", mime, content, requestPage);
            } finally { reader.releaseLock(); }
          })().catch(() => {});
        }
        return response;
      });
    };
  }

  const originalOpen = XMLHttpRequest.prototype.open;
  const xhrMetadata = new WeakMap();
  const listened = new WeakSet();
  XMLHttpRequest.prototype.open = function(method, url) {
    xhrMetadata.set(this, {url:normalize(url), page:location.href});
    if (!listened.has(this)) {
      listened.add(this);
      this.addEventListener("load", () => {
        const metadata = xhrMetadata.get(this);
        if (!metadata) return;
        try {
          const mime = this.getResponseHeader("content-type") || "";
          const text = (!this.responseType || this.responseType === "text") ? this.responseText : "";
          inspect(this.responseURL || metadata.url, "xhr", mime, text.length <= limit ? text : "", metadata.page);
        } catch (_) {}
      });
    }
    return originalOpen.apply(this, arguments);
  };

  function changedRoute() {
    if (route === location.href) return;
    route = location.href;
    sent.clear(); manifests.clear(); parents.clear(); latestManifest = null;
    post({type:"route"});
    scan();
  }
  for (const method of ["pushState", "replaceState"]) {
    const original = history[method];
    history[method] = function() { const result = original.apply(this, arguments); changedRoute(); return result; };
  }
  window.addEventListener("popstate", changedRoute);
})();
