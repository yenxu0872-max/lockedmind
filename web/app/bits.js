/* Lockedmind's motion bits: effects from React Bits (https://reactbits.dev, MIT, by David Haz),
   ported to plain JavaScript so the pages get them without React. Mark an element and it moves:

     data-split="chars|words"  SplitText: the letters (or words) rise in, when the page loads
                               (data-split-on="load") or when scrolled to. Needs GSAP + SplitText.
     data-scroll-reveal        ScrollReveal: a sentence lights up word by word as you scroll.
                               Needs GSAP + SplitText + ScrollTrigger.
     .shiny                    ShinyText: a slow shine across the text (bits.css only).
     data-spotlight            SpotlightCard: a soft light follows the pointer over a card.
     data-magnet               Magnet: a button leans toward the pointer.
     data-decrypt              DecryptedText: the text unscrambles when it comes into view.
     data-loop                 LogoLoop: the children scroll past in an endless strip, paused
                               under the pointer (fine if they arrive later, from another script).
     data-fuzzy                FuzzyText: big text with a fuzzy edge, fuzzier under the pointer.
     <html data-smooth>        Lenis smooth scrolling (darkroom.engineering, MIT), as window.lenis.

   Nothing moves for people who ask for reduced motion; the pointer effects need a mouse.
   GSAP and Lenis are copied into vendor/ and loaded only on pages that use them. */
(() => {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const mouse = matchMedia('(hover: hover) and (pointer: fine)').matches;
  const all = sel => [...document.querySelectorAll(sel)];
  const show = el => { el.style.visibility = 'visible'; };

  /* SplitText: React Bits' default "rise" — each piece from 40px down and invisible, 1.25 s,
     power3.out, 50 ms apart; on scroll it starts as the element's top passes 90% of the screen
     less 100px, once. GSAP's SplitText labels the element for screen readers and hides the
     pieces from them, and re-splits by itself when the fonts arrive or the width changes. */
  function splitText() {
    const els = all('[data-split]');
    if (!els.length) return;
    const { gsap, SplitText, ScrollTrigger } = window;
    if (still || !gsap || !SplitText) return els.forEach(show);
    gsap.registerPlugin(SplitText, ...(ScrollTrigger ? [ScrollTrigger] : []));
    for (const el of els) {
      const unit = el.dataset.split === 'words' ? 'words' : 'chars';
      const onView = el.dataset.splitOn !== 'load' && !!ScrollTrigger;
      SplitText.create(el, {
        type: unit === 'chars' ? 'words,chars' : 'words',   // letters stay inside their words, so lines break between words
        aria: 'auto',
        autoSplit: true,
        onSplit(self) {
          show(el);
          return gsap.fromTo(self[unit], { opacity: 0, y: 40 }, {
            opacity: 1, y: 0, duration: 1.25, ease: 'power3.out',
            stagger: (Number(el.dataset.delay) || 50) / 1000,
            scrollTrigger: onView ? { trigger: el, start: 'top 90%-=100px', once: true } : undefined,
          });
        },
      });
    }
  }

  /* ScrollReveal: each word starts faint and blurred (opacity .1, 4px) and comes clear as the
     sentence moves up the screen, tied to the scroll position itself. */
  function scrollReveal() {
    const els = all('[data-scroll-reveal]');
    const { gsap, SplitText, ScrollTrigger } = window;
    if (!els.length || still || !gsap || !SplitText || !ScrollTrigger) return;
    gsap.registerPlugin(SplitText, ScrollTrigger);
    for (const el of els) {
      const split = SplitText.create(el, { type: 'words', aria: 'auto' });
      gsap.fromTo(split.words, { opacity: 0.1, filter: 'blur(4px)' }, {
        opacity: 1, filter: 'blur(0px)', ease: 'none', stagger: 0.05,
        scrollTrigger: { trigger: el, start: 'top bottom-=20%', end: 'bottom bottom-=10%', scrub: true },
      });
    }
  }

  /* SpotlightCard: the card's ::before is a radial light at --mx/--my (bits.css). */
  function spotlight() {
    if (still || !mouse) return;
    for (const el of all('[data-spotlight]')) {
      el.addEventListener('pointermove', e => {
        const r = el.getBoundingClientRect();
        el.style.setProperty('--mx', `${e.clientX - r.left}px`);
        el.style.setProperty('--my', `${e.clientY - r.top}px`);
      }, { passive: true });
    }
  }

  /* Magnet: within 60px of the button it follows the pointer by a fifth of the distance, then
     settles back (React Bits' timings: .3 s in, .5 s out). */
  function magnet() {
    if (still || !mouse) return;
    const pad = 60, strength = 5;
    const els = all('[data-magnet]').map(el => ({ el, on: false }));
    if (!els.length) return;
    addEventListener('pointermove', e => {
      for (const m of els) {
        const r = m.el.getBoundingClientRect();
        const near = e.clientX > r.left - pad && e.clientX < r.right + pad && e.clientY > r.top - pad && e.clientY < r.bottom + pad;
        if (near) {
          const x = (e.clientX - (r.left + r.width / 2)) / strength, y = (e.clientY - (r.top + r.height / 2)) / strength;
          m.el.style.transition = 'transform .3s ease-out';
          m.el.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
          m.on = true;
        } else if (m.on) {
          m.el.style.transition = 'transform .5s ease-in-out';
          m.el.style.transform = '';
          m.on = false;
        }
      }
    }, { passive: true });
  }

  /* DecryptedText: when most of it is on screen, the letters scramble, then settle into the
     real text from the first letter on, one every 45 ms. Screen readers get the real text. */
  function decrypt() {
    const els = all('[data-decrypt]');
    if (!els.length || still || !('IntersectionObserver' in window)) return;
    const pool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#%&*+?';
    const run = el => {
      const text = el.textContent;
      const shown = document.createElement('span');
      shown.setAttribute('aria-hidden', 'true');
      el.setAttribute('aria-label', text);
      el.replaceChildren(shown);
      let done = 0;
      const tick = setInterval(() => {
        shown.textContent = [...text].map((c, i) => i < done || c === ' ' ? c : pool[Math.random() * pool.length | 0]).join('');
        if (done++ >= text.length) {
          clearInterval(tick);
          el.textContent = text;
          el.removeAttribute('aria-label');
        }
      }, 45);
    };
    const io = new IntersectionObserver(entries => {
      for (const en of entries) if (en.isIntersecting) { io.unobserve(en.target); run(en.target); }
    }, { threshold: 0.6 });
    els.forEach(el => io.observe(el));
  }

  /* LogoLoop: the children, then a copy of them (hidden from screen readers and the keyboard),
     slide left forever at about 40px a second; the strip fades at both ends. */
  function logoLoop() {
    if (still) return;
    for (const box of all('[data-loop]')) {
      const build = () => {
        if (box.dataset.looped || !box.children.length) return false;
        box.dataset.looped = '1';
        const items = [...box.children];
        const track = document.createElement('div');
        track.className = 'loop-track';
        items.forEach(i => track.appendChild(i));
        for (const i of items) {
          const copy = i.cloneNode(true);
          copy.setAttribute('aria-hidden', 'true');
          copy.setAttribute('tabindex', '-1');
          track.appendChild(copy);
        }
        box.appendChild(track);
        box.classList.add('looping');
        requestAnimationFrame(() => track.style.setProperty('--loop-time', `${Math.round(track.scrollWidth / 2 / 40)}s`));
        return true;
      };
      if (!build()) new MutationObserver((_, mo) => { if (build()) mo.disconnect(); }).observe(box, { childList: true });
    }
  }

  /* FuzzyText: the element's text, in its own font and colour, is drawn once off screen, then
     copied one row of pixels at a time, each row nudged sideways at random; more nudge under the
     pointer. Pauses when off screen. The canvas replaces the text only once it is drawn, so the
     plain text stays if anything fails (and for reduced motion). */
  function fuzzy() {
    if (still) return;
    for (const el of all('[data-fuzzy]')) {
      const text = el.textContent.trim();
      const css = getComputedStyle(el);
      const size = parseFloat(css.fontSize) || 120;
      const font = `${css.fontWeight} ${size}px ${css.fontFamily}`;
      const ratio = Math.min(2, devicePixelRatio || 1);
      (document.fonts?.load(font) || Promise.resolve()).catch(() => {}).then(() => {
        const off = document.createElement('canvas'), o = off.getContext('2d');
        o.font = font; o.letterSpacing = css.letterSpacing;
        const m = o.measureText(text);
        const w = Math.ceil(m.actualBoundingBoxLeft + m.actualBoundingBoxRight) + 4;
        const h = Math.ceil(m.actualBoundingBoxAscent + m.actualBoundingBoxDescent) + 4;
        off.width = w * ratio; off.height = h * ratio;
        o.scale(ratio, ratio);
        o.font = font; o.letterSpacing = css.letterSpacing;
        o.fillStyle = css.color;
        o.textBaseline = 'alphabetic';
        o.fillText(text, m.actualBoundingBoxLeft + 2, m.actualBoundingBoxAscent + 2);
        const margin = 40;
        const cv = document.createElement('canvas');
        cv.width = (w + margin * 2) * ratio; cv.height = h * ratio;
        cv.style.width = `${w + margin * 2}px`;   // height follows, and max-width can shrink it
        const ctx = cv.getContext('2d');
        let level = 0.18, live = true, frame = 0;
        const draw = () => {
          ctx.clearRect(0, 0, cv.width, cv.height);
          for (let y = 0; y < off.height; y++) {
            const dx = Math.floor(level * (Math.random() - 0.5) * 30 * ratio);
            ctx.drawImage(off, 0, y, off.width, 1, margin * ratio + dx, y, off.width, 1);
          }
          if (live) frame = requestAnimationFrame(draw);
        };
        draw();
        el.style.height = `${el.offsetHeight}px`;   // the same box as the text had: nothing below moves
        el.replaceChildren(cv);
        cv.addEventListener('pointerenter', () => { level = 0.5; });
        cv.addEventListener('pointerleave', () => { level = 0.18; });
        new IntersectionObserver(([en]) => {
          live = en.isIntersecting;
          cancelAnimationFrame(frame);
          if (live) frame = requestAnimationFrame(draw);
        }).observe(cv);
      });
    }
  }

  /* Lenis: smooth scrolling for the wheel and trackpad (touch keeps the phone's own), with
     smooth jumps to #anchors. Other scripts scroll through window.lenis.scrollTo. */
  function smooth() {
    if (still || !window.Lenis || !document.documentElement.hasAttribute('data-smooth')) return;
    window.lenis = new window.Lenis({ autoRaf: true, anchors: true });
  }

  for (const run of [smooth, splitText, scrollReveal, spotlight, magnet, decrypt, logoLoop, fuzzy]) {
    try { run(); } catch (e) { console.warn('bits:', run.name, e); all('[data-split]').forEach(show); }
  }
})();
