const fs = require('node:fs');
const vm = require('node:vm');
const posts = [];
const listeners = new Map();
const windowListeners = new Map();
class Media {
  constructor(url) { this.tagName = 'VIDEO'; this._src = url; this.duration = NaN; this.paused = false; }
  get src() { return this._src; }
  set src(value) { this._src = value; }
}
class Source extends Media {}
class Element { setAttribute() {} }
const context = {
  URL, Map, Set, WeakMap, WeakSet, Date, Math, Number, JSON, String,
  HTMLMediaElement: Media, HTMLSourceElement: Source, Element,
  XMLHttpRequest: class { open() {} },
  MutationObserver: class { observe() {} }, queueMicrotask,
  location: { href: 'https://fixture.example/player' },
  history: { pushState() {}, replaceState() {} },
  document: {
    baseURI: 'https://fixture.example/player', title: 'Audit fixture',
    querySelectorAll: () => [],
    addEventListener: (name, fn) => listeners.set(name, fn),
  },
  __webcastGeneration: 'audit',
  webkit: { messageHandlers: { videoSniffer: { postMessage: body => posts.push(body) } } },
  addEventListener: (name, fn) => windowListeners.set(name, fn),
};
context.window = context;
vm.runInNewContext(fs.readFileSync('Webcast/Sniffer/sniff.js', 'utf8'), context);
const first = new Media('https://cdn.example/playing.mp4');
listeners.get('play')({target:first});
const preload = new Media(''); preload.paused = true;
preload.src = 'https://cdn.example/not-playing.mp4';
console.log(JSON.stringify({fixture:'Playing video A, then assign src to a paused detached preload B',
reports:posts.map(p=>({url:p.url,current:p.current})),
lastCurrent:posts.filter(p=>p.current).at(-1)?.url,
preloadIsPaused:preload.paused},null,2));
