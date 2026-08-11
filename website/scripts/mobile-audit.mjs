// Mobile overflow audit: finds elements wider than the viewport on each page.
// Usage: node mobile-audit.mjs [baseUrl]
import puppeteer from "puppeteer-core";

const base = process.argv[2] ?? "http://localhost:4321";
const pages = ["/", "/how-it-works", "/for-brands", "/for-partners", "/technology", "/about", "/contact"];
const viewports = [
  { name: "iphone-375", width: 375, height: 812 },
  { name: "small-320", width: 320, height: 568 },
];

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: true,
});

let failures = 0;

for (const vp of viewports) {
  for (const path of pages) {
    const page = await browser.newPage();
    await page.setViewport({ width: vp.width, height: vp.height, isMobile: true, hasTouch: true });
    await page.goto(base + path, { waitUntil: "networkidle0", timeout: 30000 });
    await new Promise((r) => setTimeout(r, 400));

    const report = await page.evaluate(() => {
      const vw = document.documentElement.clientWidth;
      const docOverflow = document.documentElement.scrollWidth - vw;
      const offenders = [];
      document.querySelectorAll("body *").forEach((el) => {
        const r = el.getBoundingClientRect();
        if (r.width === 0) return;
        // element sticks out past the right (or left) edge of the viewport
        if (r.right > vw + 1 || r.left < -1) {
          // skip elements inside a horizontal scroller
          let p = el.parentElement;
          let insideScroller = false;
          while (p) {
            const style = getComputedStyle(p);
            if (/(auto|scroll)/.test(style.overflowX) && p.scrollWidth > p.clientWidth) {
              insideScroller = true;
              break;
            }
            p = p.parentElement;
          }
          if (insideScroller) return;
          const cls = (el.className?.baseVal ?? el.className ?? "").toString().slice(0, 80);
          const text = (el.textContent ?? "").trim().replace(/\s+/g, " ").slice(0, 60);
          offenders.push({
            tag: el.tagName.toLowerCase(),
            cls,
            text,
            left: Math.round(r.left),
            right: Math.round(r.right),
            vw,
          });
        }
      });
      return { docOverflow, offenders: offenders.slice(0, 12) };
    });

    const bad = report.docOverflow > 1 || report.offenders.length > 0;
    if (bad) failures++;
    console.log(`${bad ? "FAIL" : "ok  "} ${vp.name} ${path}  docOverflow=${report.docOverflow}px`);
    for (const o of report.offenders) {
      console.log(`      <${o.tag} class="${o.cls}"> [${o.left}..${o.right}] "${o.text}"`);
    }
    await page.close();
  }
}

await browser.close();
console.log(failures === 0 ? "ALL CLEAN" : `${failures} page/viewport combos have overflow`);
