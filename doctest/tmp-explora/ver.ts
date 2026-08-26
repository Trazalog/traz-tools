import { chromium } from '@playwright/test';
import { resolve } from 'node:path';
const nav = await chromium.launch();
const page = await (await nav.newContext({ viewport: { width: 1200, height: 1000 } })).newPage();
await page.goto('file://' + resolve('../ayuda/manual_mantenimiento.html'), { waitUntil: 'domcontentloaded', timeout: 60_000 });
await page.waitForTimeout(2000);
await page.evaluate(() => document.querySelectorAll('.section').forEach((s) => {
  const el = s as HTMLElement; el.classList.add('visible');
  el.style.display='block'; el.style.opacity='1'; el.style.transform='none';
}));
await page.waitForTimeout(600);
console.log('secciones:', await page.locator('section.section').count(),
            '· pantallas:', await page.locator('.screen-card').count(),
            '· pasos:', await page.locator('.secuencia .paso').count());
console.log('nav:', (await page.locator('.nav-item').allInnerTexts()).slice(1, 12).map((t)=>t.replace(/\s+/g,' ').trim()).join(' | '));
const a = await page.evaluate(() => ({ b: document.body.scrollWidth, w: window.innerWidth }));
console.log('scroll horizontal:', a.b > a.w ? 'SÍ' : 'no');
await nav.close();
