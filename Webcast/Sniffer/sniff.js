(() => {
  "use strict";
  if (window.__webcastInstalled) return;
  window.__webcastInstalled = true;
  // Production runs a page-world network collector and an isolated DOM/bridge observer.
  // The combined mode is useful for controlled script fixtures.
  const mode = window.__webcastMode || "combined";
  const generation = window.__webcastGeneration || "";
  const frameID = Math.random().toString(36).slice(2) + Date.now();
  const limit = 512 * 1024;
  const sent = new Map();
  const manifests = new Map();
  const parents = new Map();
  const inspections = new Set();
  let latestManifest = null;
  let activeURL = null;
  let activeElement = null;
  let activeSource = null;
  const childFrames = new WeakMap();
  // Hash routers replace pages; ordinary anchors keep the existing media observations.
  const routeKey = () => location.href.split("#")[0] + (/^#(?:\/|!)/.test(location.hash) ? location.hash : "");
  let route = routeKey();
  let routeVersion = 0;

  function remember(cache, key, value, capacity) {
    cache.delete(key);
    cache.set(key, value);
    if (cache.size > capacity) cache.delete(cache.keys().next().value);
  }

  function cancelInspections() {
    for (const stop of inspections) stop();
  }

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
    try {
      if (mode === "network") {
        if (payload.type === "route") window.postMessage({webcastRouteChanged:true}, "*");
        if (payload.url) {
          const record = {...payload, parentURL:parents.get(payload.url)};
          for (const key of Object.keys(record)) { if (record[key] === undefined) delete record[key]; }
          window.postMessage({webcastNetwork:record, webcastRouteKey:routeKey()}, "*");
        }
        return;
      }
      const body = {...payload, generation, frameID, pageURL:location.href, title:document.title.slice(0, 300)};
      for (const key of Object.keys(body)) { if (body[key] === undefined) delete body[key]; }
      window.webkit.messageHandlers.videoSniffer.postMessage(body);
    }
    catch (_) { /* A broken bridge must never break the site's player. */ }
  }

  function report(raw, source, extra = {}) {
    const url = normalize(raw);
    if (!url || !format(url, extra.mime, extra.manifest)) return;
    const record = {...extra, url, source};
    const signature = JSON.stringify(record);
    // Metadata may be unchanged when playback returns A → B → A. The activation still matters.
    const becameCurrent = extra.current === true && activeURL !== url;
    if (extra.current === true) activeURL = url;
    if (sent.get(url) === signature && !becameCurrent) return;
    remember(sent, url, signature, 200);
    post(record);
  }

  function activeVideo(video) {
    if (!video.isConnected) return;
    const raw = video.currentSrc || video.src;
    if (video !== activeElement || raw !== activeSource) deactivate();
    activeElement = video;
    activeSource = raw;
    const duration = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : undefined;
    if (normalize(raw)) {
      const cached = manifests.get(normalize(raw)) || {};
      report(raw, "video", {...cached, current:true, duration});
    } else if (String(raw).startsWith("blob:") && latestManifest) {
      // A same-frame, recent MSE request is an inference, not proof of attachment.
      const record = manifests.get(latestManifest);
      if (!record || Date.now() - record.time > 15000) return;
      const master = parents.get(latestManifest);
      // A master and its variant represent one playback; only its preferred URL is current.
      report(latestManifest, "mse", {...record, current:!master, inferred:true, duration});
      if (master) report(master, "mse", {...manifests.get(master), master:true, current:true, inferred:true, duration});
    }
  }

  function deactivate() {
    if (activeElement || activeURL) post({type:"inactive"});
    activeElement = null; activeURL = null; activeSource = null;
  }

  function sourceChanged(element) {
    if (element === activeElement || element.parentElement === activeElement) deactivate();
  }

  function inspect(raw, source, mime, text = "", requestVersion = routeVersion) {
    if (requestVersion !== routeVersion) return;
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
            try { remember(parents, new URL(line.trim(), url).href, url, 200); } catch (_) {}
            variant = false;
          }
        }
      }
      remember(manifests, url, {...extra, time:Date.now()}, 100);
      latestManifest = url;
      const master = parents.get(url);
      if (master && !extra.master && manifests.has(master)) {
        // Segment format, liveness and DRM only appear in variant playlists. Copy them to the
        // master, or the receiver parses fMP4 variants of a master playlist as MPEG-TS.
        const record = {...manifests.get(master)};
        if (extra.segmentFormat) record.segmentFormat = extra.segmentFormat;
        if (extra.live !== undefined) record.live = extra.live;
        if (extra.drm) record.drm = true;
        remember(manifests, master, record, 100);
        const {time, ...inherited} = record;
        report(master, source, inherited);
      }
    } else if (kind === "dash") {
      extra.drm = /<ContentProtection[\s>]/i.test(text);
    }
    report(url, source, extra);
    if (mode !== "network") document.querySelectorAll("video").forEach(video => { if (!video.paused) activeVideo(video); });
  }

  if (mode === "dom") window.addEventListener("message", event => {
    if (event.source !== window) return;
    // pushState runs in the page world. Re-read the actual shared location rather than
    // trusting any URL or lifecycle instruction included in a page message.
    changedRoute();
    const input = event.data && event.data.webcastNetwork;
    if (!input || typeof input !== "object" || Array.isArray(input)) return;
    if (event.data.webcastRouteKey !== routeKey()) return;
    // Page messages may only describe network media. They cannot send lifecycle/current flags,
    // frame identity or generation to the native bridge.
    const strings = {url:16384, mime:256, manifest:16, segmentFormat:8, source:16, parentURL:16384};
    const flags = ["master", "live", "drm"];
    if (Object.keys(input).length > 12) return;
    for (const [key, value] of Object.entries(input)) {
      if (strings[key]) { if (typeof value !== "string" || value.length > strings[key]) return; }
      else if (flags.includes(key)) { if (typeof value !== "boolean") return; }
      else if (key === "time") { if (typeof value !== "number" || !Number.isFinite(value)) return; }
      else return;
    }
    if (!["fetch", "xhr", "video", "source"].includes(input.source) ||
        (input.manifest !== undefined && input.manifest !== "#EXTM3U") ||
        (input.segmentFormat !== undefined && !["ts", "fmp4"].includes(input.segmentFormat))) return;
    const url = normalize(input.url);
    if (!url || !format(url, input.mime, input.manifest)) return;
    const {parentURL, time, source, ...metadata} = input;
    if (metadata.manifest === "#EXTM3U") {
      remember(manifests, url, {...metadata, time:Date.now()}, 100);
      latestManifest = url;
    }
    if (parentURL && normalize(parentURL)) remember(parents, url, normalize(parentURL), 200);
    report(url, source, metadata);
    document.querySelectorAll("video").forEach(video => { if (!video.paused) activeVideo(video); });
  });

  // Native HLS requests bypass fetch/XHR, so observe both property setters and DOM mutations.
  function hookSrc(proto) {
    const descriptor = Object.getOwnPropertyDescriptor(proto, "src");
    if (!descriptor || !descriptor.set || !descriptor.get || !descriptor.configurable) return;
    Object.defineProperty(proto, "src", {...descriptor, set(value) {
      descriptor.set.call(this, value);
      sourceChanged(this);
      report(this.src, this.tagName === "SOURCE" ? "source" : "video", {mime:this.type || ""});
    }});
  }
  hookSrc(HTMLMediaElement.prototype);
  hookSrc(HTMLSourceElement.prototype);
  const originalAttribute = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function(name, value) {
    const result = originalAttribute.apply(this, arguments);
    if (String(name).toLowerCase() === "src" && /^(VIDEO|SOURCE)$/.test(this.tagName)) {
      sourceChanged(this);
      report(this.src, this.tagName.toLowerCase(), {mime:this.type || ""});
    }
    return result;
  };
  function scan() {
    if (activeElement && (!activeElement.isConnected ||
        (activeElement.currentSrc || activeElement.src) !== activeSource)) deactivate();
    document.querySelectorAll("video, video source").forEach(element => {
      report(element.currentSrc || element.src, element.tagName.toLowerCase(), {mime:element.type || ""});
    });
  }
  let queued = false;
  function containsMedia(node) {
    return node.nodeType === 1 && (node.matches("video, source") || node.querySelector("video, source"));
  }
  function removedFrames(node) {
    if (node.nodeType !== 1 || node.isConnected) return;
    const frames = [...node.querySelectorAll("iframe, frame")];
    if (node.matches("iframe, frame")) frames.push(node);
    for (const frame of frames) {
      const child = childFrames.get(frame);
      if (child) { post({type:"frameRemoved", childFrameID:child}); childFrames.delete(frame); }
    }
  }
  // The parent can observe frame removal even when a detached child gets no pagehide event.
  // Only accept a registration from an actual direct child WindowProxy.
  if (mode !== "network") window.addEventListener("message", event => {
    const child = event.data && event.data.webcastFrameID;
    if (typeof child !== "string" || child.length > 100) return;
    const frame = [...document.querySelectorAll("iframe, frame")].find(f => f.contentWindow === event.source);
    if (!frame) return;
    const previous = childFrames.get(frame);
    if (previous && previous !== child) post({type:"frameRemoved", childFrameID:previous});
    childFrames.set(frame, child);
    post({type:"frameLinked", childFrameID:child});
  });
  function announceFrame() {
    if (window.parent !== window) window.parent.postMessage({webcastFrameID:frameID}, "*");
  }
  if (mode !== "network") {
  announceFrame();
  new MutationObserver(records => {
    for (const record of records) {
      if (record.type === "childList") record.removedNodes.forEach(removedFrames);
      else if (/^(VIDEO|SOURCE)$/.test(record.target.tagName) && record.target.src !== activeSource) sourceChanged(record.target);
    }
    if (queued) return;
    // Ordinary page updates (chat, clocks, ads without media) do not need a video rescan.
    if (!records.some(record => record.type === "attributes" ? containsMedia(record.target)
      : [...record.addedNodes, ...record.removedNodes].some(containsMedia))) return;
    queued = true;
    queueMicrotask(() => { queued = false; scan(); });
  }).observe(document, {subtree:true, childList:true, attributes:true, attributeFilter:["src"]});
  for (const event of ["play", "playing"]) {
    document.addEventListener(event, e => { if (e.target.tagName === "VIDEO") activeVideo(e.target); }, true);
  }
  for (const event of ["loadedmetadata", "durationchange"]) {
    document.addEventListener(event, e => {
      if (e.target.tagName === "VIDEO" && (e.target === activeElement || !e.target.paused)) activeVideo(e.target);
    }, true);
  }
  for (const event of ["emptied", "ended"]) {
    document.addEventListener(event, e => { if (e.target === activeElement) deactivate(); }, true);
  }
  document.addEventListener("DOMContentLoaded", scan);
  scan();
  }

  function readManifest(response, mime, requestVersion) {
    if (inspections.size >= 4 || requestVersion !== routeVersion) return;
    let reader;
    try { reader = response.clone().body.getReader(); } catch (_) { return; }
    let active = true;
    const stop = () => {
      if (!active) return;
      active = false;
      clearTimeout(timer);
      inspections.delete(stop);
      // A tee branch's cancellation promise can wait for the site's branch. Never await it.
      reader.cancel().catch(() => {});
    };
    const timer = setTimeout(stop, 5000);
    inspections.add(stop);
    (async () => {
      const decoder = new TextDecoder();
      let content = "", size = 0;
      try {
        while (active) {
          const {done, value} = await reader.read();
          if (!active || requestVersion !== routeVersion) return;
          if (done) {
            inspect(response.url, "fetch", mime, content + decoder.decode(), requestVersion);
            return;
          }
          size += value.byteLength;
          if (size > limit) return;
          content += decoder.decode(value, {stream:true});
        }
      } finally { stop(); reader.releaseLock(); }
    })().catch(() => {});
  }

  if (mode !== "dom" && window.fetch) {
    const originalFetch = window.fetch;
    window.fetch = function() {
      const requestVersion = routeVersion;
      return originalFetch.apply(this, arguments).then(response => {
        if (requestVersion !== routeVersion) return response;
        const mime = response.headers.get("content-type") || "";
        const url = response.url;
        inspect(url, "fetch", mime, "", requestVersion);
        // Inspect playlists and ambiguous plain-text endpoints, not JSON, HTML or media bodies.
        const likelyText = /mpegurl|dash\+xml|^(?:text\/plain|application\/octet-stream)(?:;|$)/i.test(mime)
          || /\.(m3u8|mpd)(?:\?|$)/i.test(url);
        const length = Number(response.headers.get("content-length"));
        if (likelyText && (!length || length <= limit) && response.body) readManifest(response, mime, requestVersion);
        return response;
      });
    };
  }

  if (mode !== "dom") {
  const originalOpen = XMLHttpRequest.prototype.open;
  const xhrMetadata = new WeakMap();
  const listened = new WeakSet();
  XMLHttpRequest.prototype.open = function(method, url) {
    xhrMetadata.set(this, {url:normalize(url), version:routeVersion});
    if (!listened.has(this)) {
      listened.add(this);
      this.addEventListener("load", () => {
        const metadata = xhrMetadata.get(this);
        if (!metadata) return;
        try {
          const mime = this.getResponseHeader("content-type") || "";
          const text = (!this.responseType || this.responseType === "text") ? this.responseText : "";
          inspect(this.responseURL || metadata.url, "xhr", mime, text.length <= limit ? text : "", metadata.version);
        } catch (_) {}
      });
    }
    return originalOpen.apply(this, arguments);
  };
  }

  function changedRoute() {
    if (route === routeKey()) return;
    route = routeKey();
    routeVersion++;
    cancelInspections();
    sent.clear(); manifests.clear(); parents.clear(); latestManifest = null;
    post({type:"route"});
    if (mode !== "network") scan();
    // A surviving player can be paused; keep its activity without inventing a new playback.
    if (mode !== "network" && activeElement) activeVideo(activeElement);
  }
  for (const method of ["pushState", "replaceState"]) {
    const original = history[method];
    history[method] = function() { const result = original.apply(this, arguments); changedRoute(); return result; };
  }
  window.addEventListener("popstate", changedRoute);
  window.addEventListener("hashchange", changedRoute);
  window.addEventListener("pagehide", () => { routeVersion++; cancelInspections(); post({type:"frameGone"}); });

  // A back/forward cache restore reuses this document without rerunning the script, but the app
  // cleared its list when the restore committed: re-announce this frame and replay its reports.
  function replay() {
    if (mode === "network") return;
    post({type:"restored"});
    announceFrame();
    // Replay the active item last, even if it was inserted before a later, now inactive video.
    for (const [url, signature] of sent) { if (url !== activeURL) post({...JSON.parse(signature), current:false}); }
    // A later DOM scan may have cached metadata without a current flag.
    if (sent.has(activeURL)) post({...JSON.parse(sent.get(activeURL)), current:true});
  }
  if (mode === "dom") window.__webcastReplay = replay;
  window.addEventListener("pageshow", event => { if (event.persisted) replay(); });
})();
