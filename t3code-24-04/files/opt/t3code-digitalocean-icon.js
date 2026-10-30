/* DigitalOcean Inference uses the Claude driver, so T3 draws Claude's mark.
   The instance accent #0080FF is the hook. The graphic is the cloud console
   favicon from https://cloud.digitalocean.com/favicon.png. */
(() => {
  const ACCENT = "#0080FF";
  const INSTANCE = "digitalocean-inference";
  const LABEL = "DigitalOcean Inference";
  const MARK = "data-do-inference-icon";
  const FAVICON =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABpklEQVR4AcXVA48dYRTH4be2HdZ2o9qIUZvfow5qR3UbVev9Ftc3zjpYG/Xpr+YZvp17kmc8c/5j47lOyQgcxj2k0AqBoB1pPMUJTDLW6pRMx330QDz6gFKsDtN4IC7iPSSEPIz323wKshBL6rDCa/MFaIBY1o1tbs1n2Gqu6MIyrfkgZCAuynEFe7ASa7ED55GAuKjGiH8FuAyBpgo70dvlKq5GHALN/T93mo13EEUxhvl4iPvhDkTxEYt+3eE+RFGK/iZAuYR4/n2j0XijXXaMCPEt6afdDrzDRMPgAESxx8KXdDVEccIweKisrEEfY6P0t+OpYZBSVt60+D85r/RIGwZtyspDFgPsUHq0Gwai2GQxwFq1TyTFFzPXAfYoAVqjCnBFCZCKonlvlCsB7vk5kPyT+347IYrD/zcAPzBUKfv2YMQ/D24lAD8wFHv5JdsPwJmhFKJ4j+n2A/DvwB5UQTS4aCgrAbAJh3ATNRAXWQz0/cD52lbXgCmGykWABiwwVC4CZDDdUFEHeIfLGGSoKAO8wX3MjuJbL2hDCg9xAKONx/oE7ZLWqbmf4UoAAAAASUVORK5CYII=";

  // Draw the favicon on the SVG that is already in the tree, and hide its
  // path. Replacing the element makes React's next commit fail.
  const paint = (svg) => {
    if (!svg.style.backgroundImage.includes("data:image/png")) {
      svg.style.backgroundImage = 'url("' + FAVICON + '")';
      svg.style.backgroundRepeat = "no-repeat";
      svg.style.backgroundPosition = "center";
      svg.style.backgroundSize = "contain";
    }
    for (const path of svg.querySelectorAll("path")) {
      if (path.getAttribute("fill") !== "transparent") path.setAttribute("fill", "transparent");
    }
    if (svg.getAttribute(MARK) !== "true") svg.setAttribute(MARK, "true");
  };

  const hideInitials = (host) => {
    for (const span of host.querySelectorAll("span")) {
      if (span.childElementCount !== 0 || span.textContent.trim() !== "DI") continue;
      if (span.style.display === "none") continue;
      span.style.setProperty("display", "none", "important");
    }
  };

  const swapHost = (host) => {
    if (!host) return;
    for (const svg of host.querySelectorAll(":scope > svg")) paint(svg);
    hideInitials(host);
  };

  const hostsIn = (container) => {
    const hosts = [];
    for (const span of container.querySelectorAll("span")) {
      if (span.querySelector(":scope > svg")) hosts.push(span);
    }
    return hosts;
  };

  const labelMatches = (value) => {
    const text = (value || "").trim();
    return text === LABEL || text.startsWith(LABEL + " ") || text.startsWith(LABEL + ":");
  };

  const scan = () => {
    if (!document.body) return;

    const accent = ACCENT.toLowerCase();
    for (const node of document.querySelectorAll("[data-provider-accent-color]")) {
      const value = (node.getAttribute("data-provider-accent-color") || "").toLowerCase();
      if (value !== accent) continue;
      if (node.querySelector(":scope > svg")) swapHost(node);
      else hostsIn(node).forEach(swapHost);
    }

    for (const node of document.querySelectorAll('[data-model-picker-provider="' + INSTANCE + '"]')) {
      hostsIn(node).forEach(swapHost);
    }

    for (const node of document.querySelectorAll("[aria-label]")) {
      if (!labelMatches(node.getAttribute("aria-label"))) continue;
      hostsIn(node).forEach(swapHost);
    }

    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    let textNode;
    while ((textNode = walker.nextNode())) {
      if (!labelMatches(textNode.textContent)) continue;
      let element = textNode.parentElement;
      for (let depth = 0; element && depth < 4; depth += 1, element = element.parentElement) {
        if ((element.textContent || "").trim().length > 80) continue;
        const hosts = hostsIn(element);
        if (hosts.length === 0 || hosts.length > 2) continue;
        hosts.forEach(swapHost);
        break;
      }
    }
  };

  let scheduled = false;
  const schedule = () => {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      scan();
    });
  };

  const start = () => {
    scan();
    new MutationObserver(schedule).observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["fill"],
    });
  };

  if (document.body) start();
  else document.addEventListener("DOMContentLoaded", start);
})();
