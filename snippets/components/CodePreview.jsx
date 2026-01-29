import React, { useEffect, useRef, useState } from 'react';
import './CodePreview.css';

export const CodePreview = ({ children }) => {
  const [instanceId] = useState(
    () => `preview-${Math.random().toString(36).slice(2)}`
  );

  useEffect(() => {
    const nav =
      document.querySelector('nav') ||
      document.querySelector('header') ||
      document.querySelector('[class*="nav"]');

    if (nav) {
      document.documentElement.style.setProperty(
        '--navbar-height',
        `${nav.offsetHeight}px`
      );
    }
  }, []);

  return (
    <div className="split-layout" data-preview-id={instanceId}>
      {children}
    </div>
  );
};

export const ContentPanel = ({ children }) => (
  <div className="content-panel">{children}</div>
);

export const ContentSection = ({ id, title, lines, children }) => (
  <div
    className="content-section"
    data-content-id={id}
    data-lines={lines}
  >
    {title && <h4>{title}</h4>}
    {children}
  </div>
);

export const CodePanel = ({
  children,
  fileName = 'config.yaml',
  showLineNumbers = false
}) => {
  const codePanelRef = useRef(null);
  const codeContentRef = useRef(null);
  const isProgrammaticScroll = useRef(false);
  const hoverTimeout = useRef(null);

  useEffect(() => {
    let tries = 0;

    const wrapLines = () => {
      const root = codeContentRef.current;
      if (!root) return;

      const pres = Array.from(root.querySelectorAll('pre'));
      if (!pres.length) {
        if (tries++ < 20) requestAnimationFrame(wrapLines);
        return;
      }

      let globalLine = 1;

      pres.forEach((pre) => {
        const code = pre.querySelector('code') || pre;
        if (!code || code.dataset.wrapped === 'true') return;

        const raw = code.textContent || '';
        let lines = raw.split('\n');

        while (lines[0] === '') lines.shift();
        while (lines[lines.length - 1] === '') lines.pop();

        code.innerHTML = lines
          .map((line) => {
            const ln = globalLine++;
            const num = showLineNumbers
              ? `<span class="line-number">${ln}</span>`
              : '';
            const safe =
              line.replace(/</g, '&lt;').replace(/>/g, '&gt;') || ' ';
            return `<span class="code-line" data-line="${ln}">${num}${safe}</span>`;
          })
          .join('');

        code.dataset.wrapped = 'true';
      });
    };

    wrapLines();
  }, [children, showLineNumbers]);

  useEffect(() => {
    const panel = codePanelRef.current;
    const content = codeContentRef.current;
    if (!panel || !content) return;

    const waitForLines = () => {
      const codeLines = content.querySelectorAll('.code-line');
      if (!codeLines.length) {
        requestAnimationFrame(waitForLines);
        return;
      }
      setupHighlighting(codeLines);
    };

    const setupHighlighting = (codeLines) => {
      const layout = panel.closest('.split-layout');
      const sections = layout.querySelectorAll('.content-section');

      const parseLines = (str) => {
        if (!str) return [];
        const out = [];
        str.split(',').forEach((p) => {
          if (p.includes('-')) {
            const [s, e] = p.split('-').map(Number);
            for (let i = s; i <= e; i++) out.push(i);
          } else {
            const n = Number(p);
            if (!isNaN(n)) out.push(n);
          }
        });
        return out;
      };

      const clearHighlight = () => {
        codeLines.forEach((l) =>
          l.classList.remove('highlighted')
        );
      };

      const highlight = (lines) => {
        clearHighlight();
        lines.forEach((n) => {
          const el = content.querySelector(
            `.code-line[data-line="${n}"]`
          );
          if (el) el.classList.add('highlighted');
        });
      };

      const scrollToLines = (lines) => {
        if (!lines.length) return;

        const first = lines[0];
        const targetLine =
          lines.length > 1 ? first : lines[0];

        const el = content.querySelector(
          `.code-line[data-line="${targetLine}"]`
        );
        if (!el) return;

        isProgrammaticScroll.current = true;

        const containerRect = content.getBoundingClientRect();
        const elRect = el.getBoundingClientRect();

        const offset =
          elRect.top - containerRect.top + content.scrollTop;

        const TOP_PADDING = 16; 

        content.scrollTo({
          top: Math.max(offset - TOP_PADDING, 0),
          behavior: 'smooth'
        });

        setTimeout(() => {
          isProgrammaticScroll.current = false;
        }, 200);
      };

      const activate = (section, scroll) => {
        if (section.classList.contains('active')) return;

        sections.forEach((s) =>
          s.classList.remove('active')
        );
        section.classList.add('active');

        const lines = parseLines(section.dataset.lines);
        highlight(lines);
        if (scroll) scrollToLines(lines);
      };

      const observer = new IntersectionObserver(
        (entries) => {
          if (isProgrammaticScroll.current) return;
          entries.forEach((e) => {
            if (e.isIntersecting)
              activate(e.target, false);
          });
        },
        {
          threshold: 0.3,
          rootMargin: '-80px 0px -40% 0px'
        }
      );

      sections.forEach((section) => {
        observer.observe(section);

        section.addEventListener('click', () =>
          activate(section, true)
        );

        section.addEventListener('mouseenter', () => {
          clearTimeout(hoverTimeout.current);
          hoverTimeout.current = setTimeout(
            () => activate(section, true),
            80
          );
        });
      });

      if (sections[0]) activate(sections[0], false);
    };

    waitForLines();
  }, []);
  
  const handleCopy = (e) => {
    const btn = e.currentTarget;

    // Extract only the code text from .code-line elements
    const codeLines = codeContentRef.current?.querySelectorAll('.code-line');
    if (!codeLines || codeLines.length === 0) return;

    // Get text from each code line, excluding line numbers and buttons
    const text = Array.from(codeLines)
      .map(line => {
        // Clone the line to avoid modifying the DOM
        const clone = line.cloneNode(true);
        // Remove line numbers if they exist
        const lineNumber = clone.querySelector('.line-number');
        if (lineNumber) lineNumber.remove();
        // Return only the text content
        return clone.textContent;
      })
      .join('\n');

    if (!text) return;

    navigator.clipboard.writeText(text).then(() => {
      btn.dataset.copied = 'true';
      setTimeout(() => (btn.dataset.copied = 'false'), 1500);
    });
  };

  return (
    <div className="code-panel" ref={codePanelRef}>
      <div className="code-header">
        {fileName}
        <button
          className="copy-btn"
          aria-label="Copy full code"
          data-copied="false"
          onClick={handleCopy}
        >
          <svg
            className="icon-copy"
            viewBox="0 0 15 16"
            fill="currentColor"
          >
            <path d="M10.113 3.124H2.205C1.463 3.124.86 3.655.86 4.31v10.005c0 .654.603 1.186 1.345 1.186h7.908c.742 0 1.345-.532 1.345-1.186V4.31c0-.655-.606-1.186-1.345-1.186Z" />
            <path d="M13.138.5H5.229c-.742 0-1.344.531-1.344 1.186 0 .23.209.414.47.414s.47-.184.47-.414c0-.197.182-.357.404-.357h7.909c.223 0 .404.16.404.357V11.69c0 .196-.181.356-.404.356-.262 0-.47.184-.47.415 0 .23.208.415.47.415.742 0 1.344-.532 1.344-1.186V1.686C14.482 1.03 13.88.5 13.138.5Z" />
          </svg>

          <svg
            className="icon-check"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fillRule="evenodd"
              d="M16.707 5.293a1 1 0 010 1.414l-7.25 7.25a1 1 0 01-1.414 0l-3.25-3.25a1 1 0 011.414-1.414l2.543 2.543 6.543-6.543a1 1 0 011.414 0z"
              clipRule="evenodd"
            />
          </svg>
        </button>
      </div>

      <div className="code-content" ref={codeContentRef}>
        {children}
      </div>
    </div>
  );
};
