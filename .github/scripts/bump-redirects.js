#!/usr/bin/env node
// Moves docs.json redirects to a newly released version (env VERSION, e.g. v2.1.x).
// Run from the repo root. Writes GITHUB_OUTPUT `changed=true` when it edits.
//
//  1. Unversioned and /latest rules that point at the previous version move to the new one.
//  2. Rules from retired versions (/v1.9.x/:slug* -> /<prev>/:slug*) move straight to the
//     new version, so visitors never take two hops.
//  3. Rules that point into the pre-release folder (<new>-SNAPSHOT) are renamed to <new>,
//     since that folder becomes the released one.
//  4. Page moves local to the previous version (e.g. sdk/* -> api-reference/sdk/*) are
//     copied to the new version when it has the same source page, so the new version
//     doesn't serve both paths.
const fs = require('fs');
const nv = process.env.VERSION;
const docs = JSON.parse(fs.readFileSync('docs.json', 'utf8'));
const R = docs.redirects;
const cur = R.find(r => r.source === '/latest/:slug*').destination.match(/\/(v[\d.x]+)\//)[1];
if (cur === nv) { console.log(`Already pointing to ${nv} — nothing to do.`); process.exit(0); }

const versionedSource = /^\/v\d+\.\d+\.x(?:-SNAPSHOT)?(?:\/|$)/;
const snap = `${nv}-SNAPSHOT`;
const stats = { moved: 0, retired: 0, renamed: 0, carried: 0 };

// 3. snapshot -> released (only when the snapshot folder is gone)
if (!fs.existsSync(snap)) {
  for (const r of R) {
    for (const k of ['source', 'destination']) {
      if (r[k].startsWith(`/${snap}/`) || r[k] === `/${snap}`) { r[k] = r[k].replace(`/${snap}`, `/${nv}`); stats.renamed++; }
    }
  }
}

for (const r of R) {
  const fromCur = r.destination === `/${cur}` || r.destination.startsWith(`/${cur}/`);
  if (!fromCur) continue;
  if (!versionedSource.test(r.source)) { r.destination = r.destination.replace(`/${cur}`, `/${nv}`); stats.moved++; }
  else if (/^\/v\d+\.\d+\.x(?:-SNAPSHOT)?\/:slug\*$/.test(r.source) && r.source.split('/')[1] !== cur && r.source.split('/')[1] !== nv
           && !fs.existsSync(r.source.split('/')[1])) { r.destination = r.destination.replace(`/${cur}`, `/${nv}`); stats.retired++; }
}

// 4. carry previous-version page moves to the new version
const pageExists = route => ['.mdx', '.md', '/index.mdx'].some(e => fs.existsSync(route.slice(1) + e));
const have = new Set(R.map(r => r.source));
const carried = [];
for (const r of R) {
  const intra = (r.source === `/${cur}` || r.source.startsWith(`/${cur}/`)) && r.destination.startsWith(`/${cur}/`);
  if (!intra) continue;
  const src = r.source.replace(`/${cur}`, `/${nv}`);
  const dst = r.destination.replace(`/${cur}`, `/${nv}`);
  if (have.has(src)) continue;
  const wildcard = src.endsWith(':slug*');
  // Only carry a rule that is still needed: the old path exists in the new version
  // (or is a wildcard whose folder exists) and the destination is real.
  const srcBase = src.replace(/\/:slug\*$/, '');
  const needed = wildcard ? fs.existsSync(srcBase.slice(1)) : pageExists(src);
  const destOk = dst.includes(':slug*') || pageExists(dst.split('#')[0]);
  if (needed && destOk) { carried.push({ source: src, destination: dst }); have.add(src); stats.carried++; }
}
if (carried.length) {
  const i = R.findIndex(r => r.source === '/latest/:slug*');
  R.splice(i < 0 ? R.length : i, 0, ...carried);
}

if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, 'changed=true\n');
fs.writeFileSync('docs.json', JSON.stringify(docs, null, 2) + '\n');
console.log(`Bumped ${cur} → ${nv}: ${JSON.stringify(stats)}`);
