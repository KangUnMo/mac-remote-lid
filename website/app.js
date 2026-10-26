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
  document.getElementById('demo-sleep').textContent = enabled ? '적용됨' : '해제됨';
  document.getElementById('demo-restore').textContent = enabled ? '복원 준비됨' : '복원 완료';
  document.getElementById('demo-summary').textContent = enabled
    ? '끄면 앱이 변경한 전원 설정을 켜기 전의 값으로 복원합니다.'
    : '앱이 변경한 전원 설정을 이전 값으로 복원했습니다.';
});

const hero = document.querySelector('.hero');
const stage = document.querySelector('.product-stage');
const story = document.querySelector('.hero-story');

if (hero && stage && story && 'IntersectionObserver' in window) {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const compact = window.matchMedia('(max-width: 900px), (max-height: 680px)');
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

  const hardware = document.querySelector('.hardware-visual');
  const copy = document.querySelector('.stage-copy');
  const backdrop = document.querySelector('.stage-backdrop');
  const wordmark = document.querySelector('.stage-wordmark');
  const meter = document.querySelector('.story-meter > span');
  const captions = [...document.querySelectorAll('.story-caption > span')];
  const layers = [hardware, preview, backdrop, wordmark, meter];
  let inView = false;
  let active = false;
  let frame = 0;

  function renderScene() {
    frame = 0;
    if (!active) return;
    const viewport = window.innerHeight;
    const rect = story.getBoundingClientRect();
    const height = story.offsetHeight;
    const small = compact.matches;
    const top = small ? 0 : parseFloat(getComputedStyle(stage).top);
    // 고정 패널의 변형과 분리된 바깥 장면을 기준으로 진행도를 계산합니다.
    const travel = small ? viewport + height : height - stage.offsetHeight;
    const progress = Math.max(0, Math.min(1, ((small ? viewport : top) - rect.top) / Math.max(1, travel)));
    const y = small ? 24 - progress * 48 : 80 - progress * 160;
    const scale = small ? .94 + progress * .08 : .9 + progress * .22;
    const angle = small ? -1.5 + progress * 3 : -5 + progress * 7;
    hardware.style.transform = `translate3d(${small ? 0 : -18 + progress * 36}px, ${y}px, 0) rotateY(${small ? 0 : -8 + progress * 12}deg) rotateZ(${angle}deg) scale(${scale})`;
    preview.style.transform = `translate3d(${small ? 0 : 20 - progress * 40}px, ${small ? 18 - progress * 36 : 76 - progress * 108}px, 0) rotateZ(${small ? 0 : 6 - progress * 8}deg)`;
    backdrop.style.transform = `translate3d(0, ${24 - progress * 48}px, 0)`;
    wordmark.style.transform = `translate3d(${progress * -36}px, ${progress * -56}px, 0)`;
    meter.style.transform = `scaleX(${progress})`;
    copy.style.opacity = small ? 1 : Math.max(0, 1 - Math.max(0, progress - .45) / .45);
    captions.forEach((caption, index) => caption.classList.toggle('is-active', index === (progress < .5 ? 0 : 1)));
  }

  function scheduleScene() {
    if (active && !frame) frame = requestAnimationFrame(renderScene);
  }

  function syncScene() {
    active = inView && !reducedMotion.matches && !document.hidden;
    if (active) {
      window.addEventListener('scroll', scheduleScene, { passive: true });
      scheduleScene();
    } else {
      window.removeEventListener('scroll', scheduleScene);
      cancelAnimationFrame(frame);
      frame = 0;
      layers.forEach(element => element.style.removeProperty('transform'));
      copy.style.removeProperty('opacity');
      captions.forEach((caption, index) => caption.classList.toggle('is-active', index === 0));
    }
  }

  const sceneObserver = new IntersectionObserver(([entry]) => {
    inView = entry.isIntersecting;
    syncScene();
  });
  sceneObserver.observe(story);
  window.addEventListener('resize', scheduleScene, { passive: true });
  document.addEventListener('visibilitychange', syncScene);
  function applyMotionPreference() {
    document.documentElement.classList.toggle('hero-motion', !reducedMotion.matches);
    if (reducedMotion.matches) {
      revealTargets.forEach(element => element.classList.remove('is-revealed'));
    }
    syncScene();
  }
  reducedMotion.addEventListener('change', applyMotionPreference);
  applyMotionPreference();
}
