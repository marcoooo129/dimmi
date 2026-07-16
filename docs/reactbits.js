/**
 * React Bits 动画组件的原生 JS 移植版
 * 无任何外部依赖，完美融入当前原生网页架构
 */
(() => {
  "use strict";

  // 1. Shiny Text (流光文字)
  // 通过 CSS 类激活，本身不需要复杂的 JS 逻辑，只需将 data 属性映射为 class
  document.querySelectorAll("[data-shiny-text]").forEach(el => {
    el.classList.add("shiny-text");
  });

  // 2. Blur Text (模糊错落显现)
  // 将文本拆分为单个字符（保留 br 换行），并加入交错延迟动画
  document.querySelectorAll("[data-blur-text]").forEach(el => {
    const splitContent = [];
    
    // 遍历子节点以正确处理文本和 <br>
    Array.from(el.childNodes).forEach(node => {
      if (node.nodeType === Node.TEXT_NODE) {
        const chars = node.textContent.split('');
        chars.forEach(char => {
          if (char.trim() === '') {
            splitContent.push(char); // 保留空格
          } else {
            splitContent.push(`<span class="blur-text-element">${char}</span>`);
          }
        });
      } else if (node.nodeName === "BR") {
        splitContent.push('<br>');
      } else {
        // 其他节点原样保留
        splitContent.push(node.outerHTML);
      }
    });
    
    // 替换原内容
    el.innerHTML = splitContent.join('');
    const elements = el.querySelectorAll(".blur-text-element");
    
    // 使用 Intersection Observer 当进入视口时触发动画
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          elements.forEach((span, index) => {
            setTimeout(() => {
              span.classList.add('show');
            }, index * 40); // 40ms 字符间隔
          });
          observer.unobserve(el);
        }
      });
    }, { threshold: 0.1 });
    
    observer.observe(el);
  });

  // 3. Magnet Button (磁吸按钮)
  // 当鼠标在按钮周围移动时，按钮产生向着鼠标方向的物理磁吸效果
  document.querySelectorAll("[data-magnet]").forEach(el => {
    const intensity = 15; // 磁吸最大位移 (px)
    
    // 在外层包裹一个 wrapper 专门用来监听鼠标，以扩大触发区域
    const parent = el.parentNode;
    const wrapper = document.createElement("div");
    wrapper.className = "magnet-wrapper";
    
    parent.insertBefore(wrapper, el);
    wrapper.appendChild(el);
    
    // 为了防止破坏原有样式布局，将 wrapper 设为 inline-flex
    wrapper.style.display = "inline-flex";
    
    wrapper.addEventListener("mousemove", (e) => {
      const rect = wrapper.getBoundingClientRect();
      const h = rect.width / 2;
      const w = rect.height / 2;
      const x = e.clientX - rect.left - h;
      const y = e.clientY - rect.top - w;
      
      const rx = (x / h) * intensity;
      const ry = (y / w) * intensity;
      
      wrapper.classList.add("active");
      wrapper.style.transform = `translate3d(${rx}px, ${ry}px, 0)`;
    });
    
    wrapper.addEventListener("mouseleave", () => {
      wrapper.classList.remove("active");
      wrapper.style.transform = `translate3d(0, 0, 0)`;
    });
  });

  // 4. Draggable Canvas Labels (自由拖拽标签)
  // 让历史和设置的解释标签可以像在 Canvas 画布上一样自由移动
  document.querySelectorAll(".showcase-label").forEach(el => {
    el.style.cursor = "grab";
    let isDragging = false;
    let startX = 0, startY = 0;
    let initialX = 0, initialY = 0;

    el.addEventListener("mousedown", (e) => {
      isDragging = true;
      el.style.cursor = "grabbing";
      el.style.zIndex = "100"; // 拖拽时置于最顶层
      
      const style = window.getComputedStyle(el);
      // 获取当前已有的 translate 偏移量
      const matrix = new DOMMatrixReadOnly(style.transform !== 'none' ? style.transform : undefined);
      initialX = matrix.m41;
      initialY = matrix.m42;
      
      startX = e.clientX;
      startY = e.clientY;
      e.preventDefault(); // 防止选中文本
    });

    document.addEventListener("mousemove", (e) => {
      if (!isDragging) return;
      const dx = e.clientX - startX;
      const dy = e.clientY - startY;
      el.style.transform = `translate3d(${initialX + dx}px, ${initialY + dy}px, 0)`;
    });

    document.addEventListener("mouseup", () => {
      if (isDragging) {
        isDragging = false;
        el.style.cursor = "grab";
        el.style.zIndex = "3"; // 恢复原有层级
      }
    });
  });

  // 5. Interactive Text Selection Demo (现场划词翻译模拟)
  const demoArea = document.getElementById("interactive-demo-area");
  const demoText = document.getElementById("demo-text");
  const demoBubble = document.getElementById("demo-bubble");

  if (demoArea && demoText && demoBubble) {
    const demoSource = document.getElementById("demo-source");
    const demoResult = document.getElementById("demo-result");
    const demoAnalysis = document.getElementById("demo-analysis");
    const demoDirection = document.getElementById("demo-direction");

    const langs = {
      zh: {
        sentence: "欢迎大家使用dimmi，我是作者Marco。",
        direction: "中文 <span>→</span> 中文",
        tokens: [
          { text: "欢迎大家", t: { zh: "欢迎大家", en: "Welcome everyone", it: "Benvenuti", fr: "Bienvenue à tous" }, a: "<strong>欢迎大家</strong><br>动词 + 代词" },
          { text: "使用", t: { zh: "使用", en: " to use", it: " a usare", fr: " pour utiliser" }, a: "<strong>使用</strong><br>动词" },
          { text: "dimmi", t: { zh: " dimmi", en: " dimmi", it: " dimmi", fr: " dimmi" }, a: "<strong>dimmi</strong><br>项目名称" },
          { text: "，我是", t: { zh: "，我是", en: ", I am", it: ", sono", fr: ", je suis" }, a: "<strong>，我是</strong><br>代词 + 系动词" },
          { text: "作者", t: { zh: "作者", en: " the author", it: " l'autore", fr: " l'auteur" }, a: "<strong>作者</strong><br>名词" },
          { text: "Marco。", t: { zh: " Marco。", en: " Marco.", it: " Marco.", fr: " Marco." }, a: "<strong>Marco。</strong><br>作者名" }
        ]
      },
      it: {
        sentence: "Benvenuti a usare dimmi, sono l'autore Marco.",
        direction: "Italiano <span>→</span> 中文",
        tokens: [
          { text: "Benvenuti", t: { zh: "欢迎大家", en: "Welcome everyone", it: "Benvenuti", fr: "Bienvenue à tous" }, a: "<strong>Benvenuti</strong><br>欢迎（benvenuto的阳性复数形式）" },
          { text: "a usare", t: { zh: "使用", en: " to use", it: " a usare", fr: " pour utiliser" }, a: "<strong>a usare</strong><br>前置词 a + 动词不定式" },
          { text: "dimmi", t: { zh: " dimmi", en: " dimmi", it: " dimmi", fr: " dimmi" }, a: "<strong>dimmi</strong><br>项目名称（意大利语意为“告诉我”）" },
          { text: ", sono", t: { zh: "，我是", en: ", I am", it: ", sono", fr: ", je suis" }, a: "<strong>sono</strong><br>我是（essere的第一人称单数）" },
          { text: "l'autore", t: { zh: "作者", en: " the author", it: " l'autore", fr: " l'auteur" }, a: "<strong>l'autore</strong><br>定冠词 l' + autore(作者)" },
          { text: "Marco.", t: { zh: " Marco。", en: " Marco.", it: " Marco.", fr: " Marco." }, a: "<strong>Marco</strong><br>作者名" }
        ]
      },
      en: {
        sentence: "Welcome everyone to use dimmi, I am the author Marco.",
        direction: "English <span>→</span> 中文",
        tokens: [
          { text: "Welcome everyone", t: { zh: "欢迎大家", en: "Welcome everyone", it: "Benvenuti", fr: "Bienvenue à tous" }, a: "<strong>Welcome everyone</strong><br>欢迎大家" },
          { text: "to use", t: { zh: "使用", en: " to use", it: " a usare", fr: " pour utiliser" }, a: "<strong>to use</strong><br>使用（动词不定式）" },
          { text: "dimmi", t: { zh: " dimmi", en: " dimmi", it: " dimmi", fr: " dimmi" }, a: "<strong>dimmi</strong><br>项目名称" },
          { text: ", I am", t: { zh: "，我是", en: ", I am", it: ", sono", fr: ", je suis" }, a: "<strong>I am</strong><br>我是" },
          { text: "the author", t: { zh: "作者", en: " the author", it: " l'autore", fr: " l'auteur" }, a: "<strong>the author</strong><br>定冠词 + 作者" },
          { text: "Marco.", t: { zh: " Marco。", en: " Marco.", it: " Marco.", fr: " Marco." }, a: "<strong>Marco</strong><br>作者名" }
        ]
      },
      fr: {
        sentence: "Bienvenue à tous pour utiliser dimmi, je suis l'auteur Marco.",
        direction: "Français <span>→</span> 中文",
        tokens: [
          { text: "Bienvenue à tous", t: { zh: "欢迎大家", en: "Welcome everyone", it: "Benvenuti", fr: "Bienvenue à tous" }, a: "<strong>Bienvenue à tous</strong><br>欢迎大家" },
          { text: "pour utiliser", t: { zh: "使用", en: " to use", it: " a usare", fr: " pour utiliser" }, a: "<strong>pour utiliser</strong><br>为了使用" },
          { text: "dimmi", t: { zh: " dimmi", en: " dimmi", it: " dimmi", fr: " dimmi" }, a: "<strong>dimmi</strong><br>项目名称" },
          { text: ", je suis", t: { zh: "，我是", en: ", I am", it: ", sono", fr: ", je suis" }, a: "<strong>je suis</strong><br>我是（être的第一人称单数）" },
          { text: "l'auteur", t: { zh: "作者", en: " the author", it: " l'autore", fr: " l'auteur" }, a: "<strong>l'auteur</strong><br>定冠词 l' + auteur(作者)" },
          { text: "Marco.", t: { zh: " Marco。", en: " Marco.", it: " Marco.", fr: " Marco." }, a: "<strong>Marco</strong><br>作者名" }
        ]
      }
    };

    // 预计算 token 的起始和结束位置
    for (let k in langs) {
      let l = langs[k];
      l.spans = [];
      l.tokens.forEach(tok => {
        let idx = l.sentence.indexOf(tok.text);
        if (idx !== -1) {
          l.spans.push({ start: idx, end: idx + tok.text.length, t: tok.t, a: tok.a });
        }
      });
      // 升序排列确保翻译组合的顺序正确
      l.spans.sort((a, b) => a.start - b.start);
    }

    let currentLangKey = "it";

    const checkSelection = () => {
      const selection = window.getSelection();
      
      // 如果有选中内容，且选中内容属于 demoText
      if (!selection.isCollapsed && demoText.contains(selection.anchorNode)) {
        const rawText = selection.toString().trim();
        if (!rawText) return; // 纯空白不弹

        const range = selection.getRangeAt(0);
        // 获取选区在文本节点中的精确起止点（半个词也能捕获到位置）
        let start = Math.min(range.startOffset, range.endOffset);
        let end = Math.max(range.startOffset, range.endOffset);

        let activeLang = langs[currentLangIn];
        let resultTranslation = "";
        let firstAnalysis = null;

        // 查找与选区有交集（重叠）的所有 token
        activeLang.spans.forEach(span => {
          // 交集条件：选区起点 < token终点 且 选区终点 > token起点
          if (start < span.end && end > span.start) {
            let translationDict = span.t;
            if (typeof translationDict === 'string') {
              resultTranslation += translationDict;
            } else {
              resultTranslation += translationDict[currentLangOut] || translationDict["zh"];
            }
            if (!firstAnalysis) firstAnalysis = span.a;
          }
        });
        
        if (resultTranslation) {
          demoSource.textContent = rawText;
          // Trim to avoid leading spaces for English/Italian translations
          demoResult.textContent = resultTranslation.trim();
          demoAnalysis.innerHTML = firstAnalysis;
        } else {
          // 兜底方案（比如只选中了标点符号）
          demoSource.textContent = rawText;
          demoResult.textContent = "...";
          demoAnalysis.innerHTML = `<strong>符号</strong><br>未提供解析`;
        }

        const rect = range.getBoundingClientRect();
        const areaRect = demoArea.getBoundingClientRect();
        
        // 计算气泡相对 demoArea 的位置
        const top = rect.bottom - areaRect.top + 12; // 选区下方 12px
        // 因为去除了 translateX(-50%)，这里直接减去卡片宽度的一半实现居中
        const left = rect.left + (rect.width / 2) - areaRect.left - (demoBubble.offsetWidth / 2); 
        
        demoBubble.style.top = `${top}px`;
        demoBubble.style.left = `${left}px`;
        
        demoBubble.classList.add("show");
      } else {
        // 如果点到了其他地方且拖拽不在进行中，可以隐藏它
        // 为了方便演示拖拽，这里就不强行隐藏了，或者只在 anchorNode 完全不相干时隐藏
        if (!demoArea.contains(selection.anchorNode)) {
          demoBubble.classList.remove("show");
        }
      }
    };
    
    // 监听选区变化
    document.addEventListener("selectionchange", checkSelection);
    
    // 让弹窗可移动 (拖拽逻辑)
    let isDraggingBubble = false;
    let bStartX = 0, bStartY = 0;
    let bInitialLeft = 0, bInitialTop = 0;

    demoBubble.style.cursor = "grab";
    
    demoBubble.addEventListener("mousedown", (e) => {
      // 避免拖动时选中文本
      if(e.target.tagName.toLowerCase() === 'p' || e.target.tagName.toLowerCase() === 'strong') return;
      
      isDraggingBubble = true;
      demoBubble.style.cursor = "grabbing";
      demoBubble.style.transition = "none"; // 拖拽时取消动画
      
      bStartX = e.clientX;
      bStartY = e.clientY;
      bInitialLeft = parseFloat(demoBubble.style.left) || 0;
      bInitialTop = parseFloat(demoBubble.style.top) || 0;
      
      e.preventDefault(); 
    });

    document.addEventListener("mousemove", (e) => {
      if (!isDraggingBubble) return;
      const dx = e.clientX - bStartX;
      const dy = e.clientY - bStartY;
      demoBubble.style.left = `${bInitialLeft + dx}px`;
      demoBubble.style.top = `${bInitialTop + dy}px`;
    });

    document.addEventListener("mouseup", () => {
      if (isDraggingBubble) {
        isDraggingBubble = false;
        demoBubble.style.cursor = "grab";
        demoBubble.style.transition = ""; // 恢复动画
      }
    });
    let currentLangIn = "it";
    let currentLangOut = "zh";

    const langNames = {
      zh: "中文",
      en: "English",
      it: "Italiano",
      fr: "Français"
    };

    const updateDirectionChip = () => {
      demoDirection.innerHTML = `${langNames[currentLangIn]} <span>→</span> ${langNames[currentLangOut]}`;
    };

    // 语言切换逻辑
    const langInBtns = document.querySelectorAll("#demo-lang-selector span[data-lang-in]");
    langInBtns.forEach(btn => {
      btn.addEventListener("click", () => {
        langInBtns.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        
        currentLangIn = btn.dataset.langIn;
        let langObj = langs[currentLangIn];
        
        demoText.textContent = langObj.sentence;
        updateDirectionChip();
        
        window.getSelection().removeAllRanges();
        demoBubble.classList.remove("show");
      });
    });

    const langOutBtns = document.querySelectorAll("#demo-lang-selector span[data-lang-out]");
    langOutBtns.forEach(btn => {
      btn.addEventListener("click", () => {
        langOutBtns.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        
        currentLangOut = btn.dataset.langOut;
        updateDirectionChip();
        
        window.getSelection().removeAllRanges();
        demoBubble.classList.remove("show");
      });
    });

    // 关闭与复制按钮逻辑
    document.getElementById("demo-close-icon").addEventListener("click", () => {
      window.getSelection().removeAllRanges();
      demoBubble.classList.remove("show");
    });

    document.getElementById("demo-copy-icon").addEventListener("click", (e) => {
      const text = demoResult.textContent;
      navigator.clipboard.writeText(text).then(() => {
        const icon = e.target;
        icon.style.opacity = "0.3";
        setTimeout(() => { icon.style.opacity = "1"; }, 400);
      });
    });

  }

  // 6. Text Type Effect (打字机效果)
  document.querySelectorAll("[data-text-type]").forEach(container => {
    const rawTexts = container.dataset.texts;
    const texts = rawTexts ? JSON.parse(rawTexts) : [
      "without borders.",
      "at your fingertips.",
      "like a native.",
      "effortlessly."
    ];
    
    const typingSpeed = parseInt(container.dataset.speed) || 50;
    const deletingSpeed = parseInt(container.dataset.deleteSpeed) || 30;
    const pauseDuration = parseInt(container.dataset.pause) || 2000;
    
    const contentSpan = document.createElement("span");
    contentSpan.className = "text-type__content";
    
    const cursorSpan = document.createElement("span");
    cursorSpan.className = "text-type__cursor";
    cursorSpan.textContent = "|";
    
    container.appendChild(contentSpan);
    container.appendChild(cursorSpan);
    
    let textIndex = 0;
    let charIndex = 0;
    let isDeleting = false;
    let timeout;
    
    const type = () => {
      const currentText = texts[textIndex];
      
      if (isDeleting) {
        if (charIndex > 0) {
          charIndex--;
          contentSpan.textContent = currentText.substring(0, charIndex);
          timeout = setTimeout(type, deletingSpeed);
        } else {
          isDeleting = false;
          textIndex = (textIndex + 1) % texts.length;
          timeout = setTimeout(type, 500); // 暂停一下再开始打字
        }
      } else {
        if (charIndex < currentText.length) {
          charIndex++;
          contentSpan.textContent = currentText.substring(0, charIndex);
          timeout = setTimeout(type, typingSpeed);
        } else {
          isDeleting = true;
          timeout = setTimeout(type, pauseDuration);
        }
      }
    };
    
    // 使用 Intersection Observer 确保可见时才开始动画
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          timeout = setTimeout(type, 800);
          observer.unobserve(container);
        }
      });
    }, { threshold: 0.1 });
    
    observer.observe(container);
  });

})();
