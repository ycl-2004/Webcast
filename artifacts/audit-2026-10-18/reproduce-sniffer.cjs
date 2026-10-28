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
const first = new Media('https://cdn.example/first.mp4');
const second = new Media('https://cdn.example/second.mp4');
for (const target of [first, second, first]) listeners.get('play')({ target });
const sequence = posts.map(p => p.url);
const expected = [first.src, second.src, first.src];
const reproduced = sequence.length === 2 && sequence.at(-1) === second.src;
const fixed = JSON.stringify(sequence) === JSON.stringify(expected);
context.document.querySelectorAll = () => [first, second];
listeners.get('DOMContentLoaded')();
const replayStart = posts.length;
windowListeners.get('pageshow')({ persisted: true });
const replay = posts.slice(replayStart).filter(p => p.url);
const cacheRestored = replay.at(-1)?.url === first.src && replay.at(-1)?.current === true;
console.log(JSON.stringify({
  fixture: 'Play A, play B, play A again with unchanged metadata',
  expected,
  observed: sequence,
  reproduced, fixed,
  cacheRestored,
}, null, 2));
if (process.argv.includes('--expect-fixed') ? !(fixed && cacheRestored) : !reproduced) process.exitCode = 1;
