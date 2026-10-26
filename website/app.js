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
