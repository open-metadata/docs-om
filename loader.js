(function() {
  const createLoader = () => {
    const existing = document.getElementById('page-loader');
    if (existing) existing.remove();

    const loader = document.createElement('div');
    loader.id = 'page-loader';
    loader.className = 'page-loader';
    document.body.appendChild(loader);

    // Animate to 70%
    requestAnimationFrame(() => loader.style.width = '70%');

    return loader;
  };

  const finishLoader = (loader) => {
    if (!loader) return;
    loader.style.width = '100%';
    setTimeout(() => loader.remove(), 300);
  };

  const observeContent = (loader) => {
    const content = document.querySelector('main') || document.body; // adjust to your main content selector
    if (!content) return;

    const observer = new MutationObserver(() => {
      finishLoader(loader);
      observer.disconnect();
    });

    observer.observe(content, { childList: true, subtree: true });
  };

  document.addEventListener('click', function(e) {
    const link = e.target.closest('a');
    const sidebarItem = e.target.closest('[href]');
    const clickedElement = link || sidebarItem;

    if (
      clickedElement &&
      clickedElement.href &&
      clickedElement.href.includes(window.location.origin) &&
      !clickedElement.href.includes('#')
    ) {
      const loader = createLoader();
      observeContent(loader);

      // Optional fallback
      setTimeout(() => finishLoader(loader), 5000);
    }
  });
})();
