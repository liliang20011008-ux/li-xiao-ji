const yearNode = document.getElementById('year');
if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}

const menuToggle = document.getElementById('menuToggle');
const siteNav = document.getElementById('siteNav');
if (menuToggle && siteNav) {
  menuToggle.addEventListener('click', () => {
    const isOpen = siteNav.classList.toggle('open');
    menuToggle.setAttribute('aria-expanded', String(isOpen));
  });

  siteNav.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      siteNav.classList.remove('open');
      menuToggle.setAttribute('aria-expanded', 'false');
    });
  });
}

const revealNodes = document.querySelectorAll('.reveal');
const revealObserver = new IntersectionObserver(
  (entries, observer) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) {
        return;
      }
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    });
  },
  { threshold: 0.16 }
);

revealNodes.forEach((node) => revealObserver.observe(node));

function animateCounter(node) {
  const target = Number(node.dataset.counter || 0);
  const durationMs = 1000;
  const start = performance.now();

  function step(now) {
    const progress = Math.min((now - start) / durationMs, 1);
    const eased = 1 - Math.pow(1 - progress, 3);
    const current = Math.floor(target * eased);
    node.textContent = target === 93 ? `${current}%` : current.toLocaleString('zh-CN');

    if (progress < 1) {
      requestAnimationFrame(step);
    }
  }

  requestAnimationFrame(step);
}

const counterNodes = document.querySelectorAll('[data-counter]');
const counterObserver = new IntersectionObserver(
  (entries, observer) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) {
        return;
      }
      animateCounter(entry.target);
      observer.unobserve(entry.target);
    });
  },
  { threshold: 0.6 }
);

counterNodes.forEach((node) => counterObserver.observe(node));
