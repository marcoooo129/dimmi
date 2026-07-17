/*
 * dimmi 自定义光标 —— 弹簧跟随的箭头 + 拖尾标签胶囊。
 *
 * 思路移植自 Framer「UserCursor」React 组件（本站是纯静态页，无 React，
 * 用 rAF + lerp 近似弹簧，逐帧更新 transform）。
 *
 * 行为：
 *   - 箭头贴着指针（快跟随），标签胶囊在后面拖尾（慢跟随），
 *     随水平速度左右微摇，按下时整体缩一下。
 *   - 标签默认写「dimmi」；悬停下载按钮（[data-site-link="release"]）
 *     时换成「download me」并转成珊瑚色。
 *   - 隐藏系统原生光标（仅精确指针设备）。触摸设备完全不启用。
 *
 * 自包含：注入自己的 <style> 与 DOM，页面只需引一行 <script defer src="cursor.js">。
 */
(() => {
  "use strict";

  // 触摸 / 粗指针设备：不启用，保留系统默认交互
  if (window.matchMedia && window.matchMedia("(pointer: coarse)").matches) return;

  const reduce =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ── 配置 ────────────────────────────────────────────────
  const SIZE = 30;                              // 箭头基准尺寸(px)
  const DEFAULT_LABEL = "dimmi";
  const DOWNLOAD_LABEL = "download me";
  const DOWNLOAD_SELECTOR = '[data-site-link="release"]';
  
  const REPO_LABEL = "code";
  const REPO_SELECTOR = '[data-site-link="repository"]';

  const MUOVERE_LABEL = "move";
  const DRAG_SELECTOR = ".showcase-label";

  const SCOPRI_LABEL = "explore";
  const FEATURE_SELECTOR = ".feature-card";

  const FLUSSO_LABEL = "workflow";
  const WORKFLOW_SELECTOR = ".workflow-grid li";

  const PRIVATO_LABEL = "privacy";
  const PRIVACY_SELECTOR = ".privacy-points li";

  const LEGGI_LABEL = "read";
  const FAQ_SELECTOR = ".faq-list summary";

  const ARROW_FILL = "#FDF6EA";                 // 奶白，暗底上亮、亮底靠描边+投影可见
  const PILL_SAND = "#F0E4CE";                  // 默认胶囊：沙色（同 App 主操作）
  const PILL_SAND_TEXT = "#6B5D52";             // 暖褐字
  const PILL_CORAL = "#F27A52";                 // 下载态胶囊：珊瑚（站点 CTA 色）
  const PILL_CORAL_TEXT = "#FFF7EF";

  // 箭头 SVG 的视觉尖端在 viewBox 里的坐标（用于把尖端对齐到指针）
  const VB = 24;
  const TIP = { x: 1.5, y: 1.5 };
  const scaleUnit = SIZE / VB;
  const tipPx = { x: TIP.x * scaleUnit, y: TIP.y * scaleUnit };

  // ── 样式 ────────────────────────────────────────────────
  const style = document.createElement("style");
  style.textContent = `
    #dimmi-cursor-label {
      position: fixed; top: 0; left: 0; z-index: 2147483000;
      pointer-events: none; will-change: transform, opacity;
      opacity: 0; transition: opacity 160ms ease;
    }
    #dimmi-cursor-label {
      display: inline-flex; align-items: center; white-space: nowrap;
      font: 600 13px/1.05 system-ui, -apple-system, "Segoe UI", Roboto,
            "Helvetica Neue", Arial, sans-serif;
      letter-spacing: 0.2px; border-radius: 999px; padding: 5px 11px;
      box-shadow: 0 6px 16px rgba(30,25,22,0.24), 0 1px 3px rgba(0,0,0,0.16);
      transform-origin: 0% 50%;
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      transition: background-color 160ms ease, color 160ms ease, opacity 160ms ease, border-color 160ms ease;
    }
    html.dimmi-cursor-visible #dimmi-cursor-label { opacity: 1; }
  `;
  document.head.appendChild(style);

  const label = document.createElement("div");
  label.id = "dimmi-cursor-label";
  label.setAttribute("aria-hidden", "true");
  const labelText = document.createElement("span");
  labelText.textContent = DEFAULT_LABEL;
  label.appendChild(labelText);
  label.style.background = PILL_SAND;
  labelText.style.color = PILL_SAND_TEXT;

  document.body.appendChild(label);
  document.documentElement.classList.add("dimmi-cursor-on");

  // ── 状态 ────────────────────────────────────────────────
  let mx = -200, my = -200;      // 目标（原始指针）
  let lx = mx, ly = my;          // 标签位置
  let scale = 1, targetScale = 1;
  let rot = 0, targetRot = 0;
  let lastX = mx, lastT = perfNow();
  let visible = false;
  let mode = null;               // "def" | "dl" | "drag"

  function perfNow() {
    return typeof performance !== "undefined" ? performance.now() : Date.now();
  }

  function setMode(newMode, customText = null) {
    if (newMode === mode && !customText) return;
    mode = newMode;
    
    // 默认样式
    let text = DEFAULT_LABEL;
    let bg = PILL_SAND;
    let color = PILL_SAND_TEXT;
    let border = "1px solid transparent";

    if (newMode === "dl") {
      text = DOWNLOAD_LABEL;
      bg = PILL_CORAL;
      color = PILL_CORAL_TEXT;
    } else if (newMode === "repo") {
      text = REPO_LABEL;
    } else if (newMode === "drag") {
      text = MUOVERE_LABEL;
      bg = "#8FB58A"; // 拖拽时用稍微不一样的绿色点缀
    } else if (newMode === "scopri") {
      text = SCOPRI_LABEL;
    } else if (newMode === "flusso") {
      text = FLUSSO_LABEL;
    } else if (newMode === "privato") {
      text = PRIVATO_LABEL;
    } else if (newMode === "leggi") {
      text = LEGGI_LABEL;
    } else if (newMode === "click") {
      text = "click";
      bg = "rgba(255, 255, 255, 0.9)";
      color = "#3A322F";
      border = "1px solid rgba(255, 255, 255, 0.4)";
    } else if (newMode === "lang") {
      text = customText || "LANG";
      bg = "rgba(255, 255, 255, 0.9)";
      color = "#3A322F";
      border = "1px solid rgba(255, 255, 255, 0.4)";
    }

    labelText.textContent = text;
    label.style.background = bg;
    labelText.style.color = color;
    label.style.border = border;
  }

  function show() {
    if (visible) return;
    visible = true;
    document.documentElement.classList.add("dimmi-cursor-visible");
  }
  function hide() {
    if (!visible) return;
    visible = false;
    document.documentElement.classList.remove("dimmi-cursor-visible");
  }

  // ── 指针事件 ────────────────────────────────────────────
  window.addEventListener(
    "mousemove",
    (e) => {
      mx = e.clientX;
      my = e.clientY;

      // 水平速度 → 标签左右微摇
      const now = perfNow();
      const dt = Math.max(1, now - lastT);
      const vx = ((e.clientX - lastX) / dt) * 1000; // px/s
      lastX = e.clientX;
      lastT = now;
      const norm = Math.min(1, Math.abs(vx) / 1500);
      targetRot = (vx === 0 ? 0 : vx > 0 ? 1 : -1) * norm * 16; // ±16°

      show();

      // 悬停判定（光标层 pointer-events:none，e.target 即底层真实元素）
      const t = e.target;
      let hoverState = "def";
      let customText = null;
      if (t && t.closest) {
        if (t.closest(DOWNLOAD_SELECTOR)) {
          hoverState = "dl";
        } else if (t.closest(REPO_SELECTOR)) {
          hoverState = "repo";
        } else if (t.closest(DRAG_SELECTOR)) {
          hoverState = "drag";
        } else if (t.closest(FAQ_SELECTOR)) {
          hoverState = "leggi";
        } else if (t.closest(WORKFLOW_SELECTOR)) {
          hoverState = "flusso";
        } else if (t.closest(PRIVACY_SELECTOR)) {
          hoverState = "privato";
        } else if (t.closest(".language-cloud span")) {
          hoverState = "lang";
          customText = t.closest(".language-cloud span").dataset.langName;
        } else if (t.closest("a, button, .clickable, .demo-lang-selector span, .card-icons span, .lang-balls .lang-ball")) {
          hoverState = "click";
        } else if (t.closest(FEATURE_SELECTOR)) {
          hoverState = "scopri";
        }
      }
      setMode(hoverState, customText);
    },
    { passive: true }
  );

  window.addEventListener("mousedown", () => (targetScale = 0.9));
  window.addEventListener("mouseup", () => (targetScale = 1));

  // 离开 / 回到窗口
  document.addEventListener("mouseout", (e) => {
    if (!e.relatedTarget && !e.toElement) hide();
  });
  window.addEventListener("blur", hide);
  document.addEventListener("mouseenter", show);

  // ── 逐帧渲染 ────────────────────────────────────────────
  const aLerp = reduce ? 1 : 0.42; // 箭头快跟随
  const lLerp = reduce ? 1 : 0.17; // 标签慢拖尾
  const labelOffX = SIZE * 0.85;
  const labelOffY = SIZE * 0.5;

  function frame() {
    lx += (mx - lx) * lLerp;
    ly += (my - ly) * lLerp;
    scale += (targetScale - scale) * 0.25;
    rot += (targetRot - rot) * 0.15;
    if (!reduce) targetRot *= 0.9; // 无输入时回正

    // 标签在指针右下方拖尾
    label.style.transform =
      `translate(${lx + labelOffX}px, ${ly + labelOffY}px) rotate(${rot}deg) scale(${scale})`;

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
