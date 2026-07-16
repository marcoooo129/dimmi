/*
 * SpotlightCard —— 光标跟随的柔和暖光（React Bits「SpotlightCard」的原生移植）。
 *
 * 逻辑很轻：鼠标在卡片内移动时，把卡片内的相对坐标写进 CSS 变量
 * --spot-x / --spot-y；卡片的 ::before 用一个 radial-gradient 跟着这两个变量走，
 * hover 时淡入。全部视觉在 CSS 里，这里只喂坐标。
 *
 * 触摸设备不启用（没有 hover 概念）。
 */
(() => {
  "use strict";

  if (window.matchMedia && window.matchMedia("(pointer: coarse)").matches) return;

  const cards = document.querySelectorAll(".privacy-points li");
  cards.forEach((card) => {
    card.addEventListener(
      "mousemove",
      (e) => {
        const r = card.getBoundingClientRect();
        card.style.setProperty("--spot-x", `${e.clientX - r.left}px`);
        card.style.setProperty("--spot-y", `${e.clientY - r.top}px`);
      },
      { passive: true }
    );
  });
})();
