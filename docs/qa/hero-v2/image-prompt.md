# 히어로 V2 이미지 제작 기록

내장 image_gen 도구로 생성하고, 데스크톱 장치의 비율을 한 번 수정했습니다. 투명도는 유지했습니다. 최종 웹 에셋은 WebP로 변환했으며 원본 PNG는 로컬 build/hero-v2-source.png에 보관합니다.

## 최초 프롬프트

```text
Use case: product-mockup.
Asset type: transparent hardware hero image for a Korean macOS utility landing page. A finished, premium product visualization, not a website screenshot.
Primary request: create a photorealistic CGI group of three elegant silver aluminium Mac-inspired computers: a thin 14-inch laptop as the dominant subject, a compact low square desktop computer, and a taller square desktop workstation. The laptop lid is open only about 30 degrees, showing a dark navy screen and a precisely modeled keyboard deck. The low desktop sits toward the left foreground, the taller desktop behind it. All three form one coherent, carefully art-directed group with clear individual silhouettes.
Composition: landscape 1536 by 1024 composition, isolated objects centered with comfortable transparent padding on every side, front three-quarter view from slightly above. Products occupy about 85 percent of the image width. No separate floor or backdrop. This image will sit on a deep blue-green website background and have HTML interface panels layered beside it.
Materials and lighting: premium industrial design photography, finely brushed silver aluminium, accurate chamfered edges, understated black glass, physically plausible ports, broad soft studio key light, crisp controlled cool rim light with a very subtle pale mint reflection. Deep but readable shadows and natural specular highlights. High craft, restrained, convincingly three dimensional. Preserve clean fine edges and translucent soft contact shadows.
Text: none. No logos, letters, brand marks, UI, headlines, icons, watermarks, cables, people, decorative rings, neon beams, or colored backdrop. Keep the render genuinely transparent. Do not reproduce a flat CSS illustration.
```

## 비율 수정 프롬프트

```text
Edit only the tall aluminium computer at the upper left of this transparent product render. It currently looks like a tall tower. Replace it with a compact desktop workstation shaped like a low rounded square aluminium box, about twice the height of the small desktop computer at the lower left, with its total width unchanged. The workstation should look like a compact Mac Studio-style desktop, not a tower. Leave the laptop, small low desktop computer, lighting, material quality, camera perspective, transparency, padding and overall composition unchanged. Keep all three devices physically plausible and cleanly separated. No logos, extra props or text. Preserve genuine transparency.
```
