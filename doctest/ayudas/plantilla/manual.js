/*
 * manual.js — comportamiento compartido de los manuales de ayuda.
 *
 * Extraído del sitio publicado (ayudatrazalogtools), donde estaba repetido dentro
 * de cada manual: barra de progreso, resaltado de la sección activa al hacer
 * scroll, botón de volver arriba y el menú lateral en pantallas chicas.
 */

// ── Progress bar ──────────────────────────────────────────────
const progressBar = document.getElementById('progress-bar');
window.addEventListener('scroll', () => {
  const doc = document.documentElement;
  const scrolled = doc.scrollTop / (doc.scrollHeight - doc.clientHeight);
  progressBar.style.transform = `scaleX(${scrolled})`;
  // Back to top
  document.getElementById('back-top').classList.toggle('visible', window.scrollY > 300);
  // Active nav
  updateActiveNav();
});

// ── Active nav from scroll ────────────────────────────────────
function updateActiveNav() {
  const sections = document.querySelectorAll('section[id]');
  const navItems = document.querySelectorAll('.nav-item');
  let current = 'cover';
  sections.forEach(s => {
    if (window.scrollY >= s.offsetTop - 100) current = s.id;
  });
  navItems.forEach(item => {
    const href = item.getAttribute('href');
    item.classList.toggle('active', href === '#' + current);
  });
}

// ── Nav click ─────────────────────────────────────────────────
function setActive(el) {
  document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
  el.classList.add('active');
  if (window.innerWidth < 900) closeSidebar();
}

// ── Mobile sidebar ────────────────────────────────────────────
function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
  document.getElementById('overlay').style.display =
    document.getElementById('sidebar').classList.contains('open') ? 'block' : 'none';
}
function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('overlay').style.display = 'none';
}

// ── Intersection Observer for fade-in ────────────────────────
const observer = new IntersectionObserver(entries => {
  entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); });
}, { threshold: 0.05 });
document.querySelectorAll('.section').forEach(s => observer.observe(s));
