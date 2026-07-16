(() => {
  "use strict";

  const config = window.DIMMI_SITE_CONFIG || {};
  const targets = {
    repository: config.repositoryUrl,
    release: config.releaseUrl
  };

  document.querySelectorAll("[data-site-link]").forEach((link) => {
    const kind = link.getAttribute("data-site-link");
    const url = targets[kind];

    if (typeof url === "string" && /^https:\/\/github\.com\//.test(url)) {
      link.href = url;
      link.classList.remove("is-pending");
      if (kind === "repository") {
        link.rel = "noopener noreferrer";
      }
      return;
    }

    link.href = "#release-status";
    link.classList.add("is-pending");
    link.title = "GitHub 账号与仓库确认后启用";
  });

  const reviewBanner = document.querySelector("[data-review-banner]");
  if (reviewBanner && config.reviewMode === false) {
    reviewBanner.hidden = true;
  }

  const linkStatus = document.querySelector("[data-link-status]");
  if (linkStatus && targets.release) {
    linkStatus.hidden = true;
  }

  document.querySelectorAll("[data-current-year]").forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });
})();
