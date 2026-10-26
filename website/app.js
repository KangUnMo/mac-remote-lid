'use strict';

const toggle = document.getElementById('demo-toggle');
const preview = document.getElementById('demo-window');
const state = document.getElementById('demo-state');

toggle.addEventListener('click', () => {
  const enabled = toggle.getAttribute('aria-checked') !== 'true';
  toggle.setAttribute('aria-checked', String(enabled));
  preview.classList.toggle('is-off', !enabled);
  state.replaceChildren();
  const dot = document.createElement('span');
  dot.className = 'status-dot';
  dot.setAttribute('aria-hidden', 'true');
  state.append(dot, enabled ? ' 원격 모드 켜짐' : ' 이전 설정으로 복원됨');
});

const hero = document.querySelector('.hero');
const stage = document.querySelector('.product-stage');

if (hero && stage && 'IntersectionObserver' in window) {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const compact = window.matchMedia('(max-width: 700px)');
  const revealTargets = hero.querySelectorAll('[data-reveal]');
  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      revealObserver.unobserve(entry.target);
      if (!reducedMotion.matches) entry.target.classList.add('is-revealed');
    });
  }, { rootMargin: '0px 0px 64px 0px', threshold: 0 });

  revealTargets.forEach((element, index) => {
    element.style.setProperty('--reveal-delay', `${element === stage ? 0 : Math.min(index, 4) * 60}ms`);
    revealObserver.observe(element);
  });

  hero.addEventListener('animationend', event => {
    if (event.target.matches('[data-reveal]')) event.target.classList.remove('is-revealed');
  });
  hero.addEventListener('focusin', event => {
    const element = event.target.closest('[data-reveal]');
    if (!element) return;
    element.classList.remove('is-revealed');
    revealObserver.unobserve(element);
  });

  const layers = [...stage.querySelectorAll('[data-parallax]')].map(element => ({
    element,
    depth: Number(element.dataset.parallax)
  }));
  let inView = false;
  let active = false;
  let frame = 0;

  function renderParallax() {
    frame = 0;
    if (!active) return;
    const viewport = window.innerHeight;
    const height = stage.offsetHeight;
    // 등장 중인 패널의 transform 영향을 받지 않는 레이아웃 좌표를 사용합니다.
    const center = hero.getBoundingClientRect().top + stage.offsetTop + height / 2;
    const progress = Math.max(-1, Math.min(1, (viewport / 2 - center) / Math.max(1, (viewport + height) / 2)));
    const distance = progress * (compact.matches ? 8 : 28);
    layers.forEach(({ element, depth }) => {
      element.style.transform = `translate3d(0, ${(distance * depth).toFixed(2)}px, 0)`;
    });
  }

  function scheduleParallax() {
    if (active && !frame) frame = requestAnimationFrame(renderParallax);
  }

  function syncParallax() {
    active = inView && !reducedMotion.matches && !document.hidden;
    if (active) {
      window.addEventListener('scroll', scheduleParallax, { passive: true });
      scheduleParallax();
    } else {
      window.removeEventListener('scroll', scheduleParallax);
      cancelAnimationFrame(frame);
      frame = 0;
      layers.forEach(({ element }) => element.style.removeProperty('transform'));
    }
  }

  const stageObserver = new IntersectionObserver(([entry]) => {
    inView = entry.isIntersecting;
    syncParallax();
  });
  stageObserver.observe(stage);
  window.addEventListener('resize', scheduleParallax, { passive: true });
  document.addEventListener('visibilitychange', syncParallax);
  reducedMotion.addEventListener('change', () => {
    if (reducedMotion.matches) {
      revealTargets.forEach(element => element.classList.remove('is-revealed'));
    }
    syncParallax();
  });
}
