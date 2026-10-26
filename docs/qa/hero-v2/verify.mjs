import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';

const read = name => readFile(new URL(name, import.meta.url), 'utf8');
const desktop = JSON.parse(await read('desktop-measurements.json'));
const mobile = JSON.parse(await read('mobile-measurements.json'));
const interactions = JSON.parse(await read('interaction-results.json'));
const accessibility = JSON.parse(await read('accessibility-network-results.json'));
const [start, , end] = desktop;

assert(start.hardwareY - end.hardwareY >= 150, '제품 이동은 최소 150px이어야 합니다.');
assert(start.previewY - end.previewY >= 100, '앱 창 이동은 최소 100px이어야 합니다.');
assert(end.hardwareScale - start.hardwareScale >= .2);
assert(Math.abs(start.stageTop - end.stageTop) < 1, '장면 고정 위치가 유지되어야 합니다.');
assert.equal(end.copyOpacity, 0);
assert(desktop.every(row => row.cardInside && row.overflow <= 0));
assert(mobile.every(row => row.width === 390 && row.overflow <= 0 && row.stagePosition === 'relative'));
assert(Math.abs(mobile[0].hardwareY - mobile[2].hardwareY) < 48);
assert.equal(interactions.toggleOff.restore, '복원 완료');
assert.equal(interactions.keyboardSpaceRestoresOn, true);
assert.equal(interactions.download.bytes, 976132);
assert.equal(interactions.download.sha256, '92fff17a3e58490baedaff27a49f6e3e6fbc0b88b4158d36a8fbec5e272d7e9f');
assert.equal(accessibility.reducedMotion.hardwareTransform, 'none');
assert.equal(accessibility.reducedMotion.previewTransform, 'none');
assert.equal(accessibility.reducedMotion.storyHeight, accessibility.reducedMotion.stageHeight);
assert.equal(accessibility.reducedMotion.meterDisplay, 'none');
assert.equal(accessibility.motionResumedAfterPreferenceChange, true);
assert.equal(accessibility.consoleAndNetworkErrors.length, 0);

const html = await read('../../../website/index.html');
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
assert.equal(ids.length, new Set(ids).size, 'HTML id가 중복되면 안 됩니다.');
for (const match of html.matchAll(/\b(?:src|srcset)="([^"]+)"/g)) {
  if (!/^(?:https?:|data:)/.test(match[1])) {
    assert((await stat(new URL('../../../website/' + match[1], import.meta.url))).isFile());
  }
}
const css = await read('../../../website/styles.css');
assert.equal((css.match(/{/g) || []).length, (css.match(/}/g) || []).length);
console.log('저장된 에고 검증 기록과 현재 정적 자원 검사를 통과했습니다. 브라우저를 다시 실행하지는 않습니다.');
