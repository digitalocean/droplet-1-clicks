/* Adds DigitalOcean Inference to Paperclip when /digitalocean-inference.json
   says inference is already configured.

   Onboarding's "Connect a model" row only recommends Claude and OpenAI, and a
   typed key on the OpenAI tile is checked against api.openai.com. The new-agent
   dialog only lists real adapters, and OpenCode is the adapter that can call
   DigitalOcean. These tiles hire opencode_local on digitalocean/<model>. The
   saved adapter type stays opencode_local. Visible labels say DigitalOcean.
   The model access key stays in the server environment
   (PAPERCLIP_OPENCODE_PROVIDERS). */
(() => {
  const MARK = "data-do-inference";
  const NEW_AGENT_MARK = "data-do-new-agent";
  const STORAGE_KEY = "paperclip-onboarding-state";
  const FAVICON =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABpklEQVR4AcXVA48dYRTH4be2HdZ2o9qIUZvfow5qR3UbVev9Ftc3zjpYG/Xpr+YZvp17kmc8c/5j47lOyQgcxj2k0AqBoB1pPMUJTDLW6pRMx330QDz6gFKsDtN4IC7iPSSEPIz323wKshBL6rDCa/MFaIBY1o1tbs1n2Gqu6MIyrfkgZCAuynEFe7ASa7ED55GAuKjGiH8FuAyBpgo70dvlKq5GHALN/T93mo13EEUxhvl4iPvhDkTxEYt+3eE+RFGK/iZAuYR4/n2j0XijXXaMCPEt6afdDrzDRMPgAESxx8KXdDVEccIweKisrEEfY6P0t+OpYZBSVt60+D85r/RIGwZtyspDFgPsUHq0Gwai2GQxwFq1TyTFFzPXAfYoAVqjCnBFCZCKonlvlCsB7vk5kPyT+347IYrD/zcAPzBUKfv2YMQ/D24lAD8wFHv5JdsPwJmhFKJ4j+n2A/DvwB5UQTS4aCgrAbAJh3ATNRAXWQz0/cD52lbXgCmGykWABiwwVC4CZDDdUFEHeIfLGGSoKAO8wX3MjuJbL2hDCg9xAKONx/oE7ZLWqbmf4UoAAAAASUVORK5CYII=";

  let config = null;
  let busy = false;
  let newAgentBusy = false;
  let newAgentSelected = false;
  let draftName = "";
  let scheduled = false;
  let companiesCache = null;
  let doAgents = [];
  let doAgentsPath = "";

  const isOpenCodeModel = (value) => {
    if (typeof value !== "string") return false;
    const trimmed = value.trim();
    const slash = trimmed.indexOf("/");
    return slash > 0 && slash < trimmed.length - 1;
  };

  const status = (text, isError) => {
    let node = document.getElementById("do-inference-status");
    if (!node) {
      node = document.createElement("div");
      node.id = "do-inference-status";
      node.setAttribute("role", "status");
      node.style.cssText = [
        "position:fixed",
        "left:50%",
        "bottom:24px",
        "transform:translateX(-50%)",
        "z-index:80",
        "max-width:min(420px, calc(100% - 32px))",
        "padding:10px 14px",
        "border-radius:8px",
        "color:#fff",
        "font:13px/1.4 ui-sans-serif, system-ui, sans-serif",
        "text-align:center",
      ].join(";");
      document.body.appendChild(node);
    }
    node.style.background = isError ? "#7f1d1d" : "#111";
    node.textContent = text;
  };

  const readDraft = () => {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      return parsed && typeof parsed === "object" ? parsed : null;
    } catch {
      return null;
    }
  };

  const errorMessage = async (response) => {
    const body = await response.json().catch(() => null);
    if (body && typeof body.error === "string" && body.error) return body.error;
    if (body && typeof body.message === "string" && body.message) return body.message;
    return "Could not connect DigitalOcean Inference (" + response.status + ").";
  };

  const companyPrefix = async (companyId, draft) => {
    const saved = draft && typeof draft.createdCompanyPrefix === "string"
      ? draft.createdCompanyPrefix.trim()
      : "";
    if (saved) return saved;
    const listed = await fetch("/api/companies?scope=accessible", {
      credentials: "include",
      headers: { Accept: "application/json" },
    });
    if (!listed.ok) return "";
    const companies = await listed.json().catch(() => []);
    if (!Array.isArray(companies)) return "";
    const found = companies.find((company) => company && company.id === companyId);
    return found && typeof found.issuePrefix === "string" ? found.issuePrefix.trim() : "";
  };

  const leaveOnboarding = async (companyId, draft) => {
    // Bare /onboarding always reopens on "name your organization" after a
    // reload, even when the draft is further along. Leave that route.
    try {
      window.localStorage.removeItem(STORAGE_KEY);
    } catch {
      // A private-mode storage failure should not keep the hired agent hidden.
    }
    const prefix = await companyPrefix(companyId, draft);
    window.location.assign(prefix ? "/" + encodeURIComponent(prefix) + "/dashboard" : "/");
  };

  const resumeAgent = async (agentId, companyId) => {
    const response = await fetch(
      "/api/agents/" + encodeURIComponent(agentId) + "/resume?companyId=" + encodeURIComponent(companyId),
      {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: "{}",
      },
    );
    if (!response.ok) throw new Error(await errorMessage(response));
    return response.json();
  };

  const waitForRunnableAgent = async (agentId, companyId, initialAgent) => {
    const lifecycle = initialAgent && typeof initialAgent.lifecycleState === "string"
      ? initialAgent.lifecycleState
      : "";
    const legacyStatus = initialAgent && typeof initialAgent.status === "string"
      ? initialAgent.status
      : "";
    // New hires enter preparing/verifying asynchronously. Their compatibility
    // status is "paused", but they are not actually paused: the lifecycle
    // worker will transition verifying → ready. Resume is invalid until the
    // lifecycle state is exactly paused.
    if (lifecycle === "paused" || (!lifecycle && legacyStatus === "paused")) {
      status("Starting your DigitalOcean agent…", false);
      await resumeAgent(agentId, companyId);
    }
  };

  const connect = async (button) => {
    if (busy || !config) return;
    const draft = readDraft();
    const companyId = draft && typeof draft.createdCompanyId === "string" ? draft.createdCompanyId : "";
    if (!companyId) {
      status("Finish the organization step, then choose DigitalOcean Inference.", true);
      return;
    }
    const name = draft && typeof draft.agentName === "string" && draft.agentName.trim()
      ? draft.agentName.trim()
      : "Agent";
    const role = draft && typeof draft.agentRole === "string" && draft.agentRole.trim()
      ? draft.agentRole.trim()
      : "general";

    busy = true;
    button.disabled = true;
    status("Connecting DigitalOcean Inference…", false);
    try {
      const listed = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agents", {
        credentials: "include",
        headers: { Accept: "application/json" },
      });
      let existingId = "";
      let selectedAgent = null;
      if (listed.ok) {
        const agents = await listed.json().catch(() => []);
        if (Array.isArray(agents)) {
          const found = agents.find((agent) =>
            agent &&
            typeof agent.name === "string" &&
            agent.name.trim().toLowerCase() === name.toLowerCase() &&
            agent.adapterType === "opencode_local" &&
            typeof agent.id === "string"
          );
          if (found) {
            existingId = found.id;
            selectedAgent = found;
          }
        }
      }

      let agentId = existingId;
      if (!agentId) {
        const hired = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agent-hires", {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({
            name: name,
            role: role,
            adapterType: "opencode_local",
            adapterConfig: {
              model: config.model,
              dangerouslySkipPermissions: true,
            },
            onboardingFirstAgent: true,
            runtimeConfig: {},
          }),
        });
        if (!hired.ok) throw new Error(await errorMessage(hired));
        const hire = await hired.json();
        if (hire && hire.approval && typeof hire.approval.id === "string") {
          const approved = await fetch("/api/approvals/" + encodeURIComponent(hire.approval.id) + "/approve", {
            method: "POST",
            credentials: "include",
            headers: { "Content-Type": "application/json", Accept: "application/json" },
            body: JSON.stringify({
              decisionNote: "Approved during onboarding first-agent setup.",
            }),
          });
          if (!approved.ok) throw new Error(await errorMessage(approved));
        }
        const agent = hire && hire.agent ? hire.agent : hire;
        agentId = agent && typeof agent.id === "string" ? agent.id : "";
        if (!agentId) throw new Error("DigitalOcean Inference connected, but no agent id was returned.");
        selectedAgent = agent;
      }

      await waitForRunnableAgent(agentId, companyId, selectedAgent);

      status("DigitalOcean Inference connected. Opening the organization…", false);
      await leaveOnboarding(companyId, draft);
    } catch (error) {
      busy = false;
      button.disabled = false;
      status(error instanceof Error ? error.message : "Could not connect DigitalOcean Inference.", true);
    }
  };

  const paint = (group) => {
    const collapsed = group.className.indexOf("justify-center") !== -1;
    const existing = group.querySelector("[" + MARK + '="1"]');
    if (collapsed) {
      if (existing) existing.remove();
      return;
    }
    if (existing) return;

    const wrappers = Array.from(group.querySelectorAll(":scope > div"));
    const sample = wrappers.find((wrapper) => {
      const button = wrapper.querySelector("button");
      return button && button.getAttribute("aria-checked") !== "true";
    }) || wrappers.find((wrapper) => wrapper.querySelector("button"));
    if (!sample) return;

    const tile = sample.cloneNode(true);
    tile.setAttribute(MARK, "1");
    const button = tile.querySelector("button");
    if (!button) return;
    button.setAttribute("aria-checked", "false");
    button.setAttribute("aria-label", "DigitalOcean Inference");
    button.type = "button";

    const iconHost = button.querySelector("span");
    if (iconHost) {
      iconHost.textContent = "";
      const image = document.createElement("img");
      image.alt = "";
      image.width = 30;
      image.height = 30;
      image.src = FAVICON;
      image.style.width = "30px";
      image.style.height = "30px";
      image.style.objectFit = "contain";
      iconHost.appendChild(image);
    }

    const label = Array.from(button.querySelectorAll("span")).find((span) =>
      String(span.className).indexOf("font-medium") !== -1
    );
    if (label) label.textContent = config.label || "DigitalOcean";

    const tag = Array.from(button.querySelectorAll("span")).find((span) => {
      const text = span.textContent.trim();
      // v2026.916.1 used "API". v2026.1023.0 uses "API key" and can show
      // "Custom Gateway" on an advanced source.
      return text === "API" || text === "API key" || text === "Subscription" || text === "Custom Gateway" || text === "Inference";
    });
    if (tag) tag.textContent = config.tag || "Inference";

    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      void connect(button);
    });
    group.appendChild(tile);
  };

  const currentPrefix = () => {
    const parts = window.location.pathname.split("/").filter(Boolean);
    return parts.length ? parts[0] : "";
  };

  const loadCompanies = async () => {
    if (companiesCache) return companiesCache;
    const listed = await fetch("/api/companies?scope=accessible", {
      credentials: "include",
      headers: { Accept: "application/json" },
    });
    if (!listed.ok) return [];
    const companies = await listed.json().catch(() => []);
    companiesCache = Array.isArray(companies) ? companies : [];
    return companiesCache;
  };

  const companyIdForPath = async () => {
    const prefix = currentPrefix().toLowerCase();
    if (!prefix || prefix === "agents" || prefix === "onboarding") return "";
    const companies = await loadCompanies();
    const found = companies.find((company) =>
      company &&
      typeof company.issuePrefix === "string" &&
      company.issuePrefix.toLowerCase() === prefix &&
      typeof company.id === "string"
    );
    return found ? found.id : "";
  };

  const refreshDoAgents = () => {
    const path = window.location.pathname;
    if (doAgentsPath === path) return;
    doAgentsPath = path;
    void (async () => {
      const companyId = await companyIdForPath();
      if (!companyId) {
        doAgents = [];
        return;
      }
      const listed = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agents", {
        credentials: "include",
        headers: { Accept: "application/json" },
      });
      if (!listed.ok || window.location.pathname !== path) return;
      const agents = await listed.json().catch(() => []);
      if (!Array.isArray(agents) || window.location.pathname !== path) return;
      doAgents = agents.filter((agent) =>
        agent &&
        agent.adapterType === "opencode_local" &&
        agent.adapterConfig &&
        typeof agent.adapterConfig.model === "string" &&
        agent.adapterConfig.model.indexOf("digitalocean/") === 0 &&
        typeof agent.id === "string"
      );
      relabelDigitalOcean();
    })();
  };

  const viewingDoAgent = () => {
    const parts = window.location.pathname.split("/").filter(Boolean);
    const index = parts.indexOf("agents");
    const agentId = index >= 0 ? parts[index + 1] : "";
    if (!agentId || agentId === "all" || agentId === "new") return false;
    return doAgents.some((agent) => agent.id === agentId);
  };

  const relabelDigitalOcean = () => {
    document.querySelectorAll('input[aria-label="Search or paste a model ID"]').forEach((input) => {
      const searchWrap = input.parentElement;
      const header = searchWrap && searchWrap.previousElementSibling;
      const list = searchWrap && searchWrap.parentElement
        ? searchWrap.parentElement.querySelector('[role="listbox"][aria-label="Models"]')
        : null;
      if (!header || !list || list.textContent.indexOf("digitalocean/") === -1) return;
      const title = Array.from(header.querySelectorAll("span")).find((span) =>
        span.textContent.trim() === "Choose model" || span.textContent.trim() === "Choose model for DigitalOcean"
      );
      const subtitle = Array.from(header.querySelectorAll("span")).find((span) =>
        span.textContent.trim() === "OpenCode" || span.textContent.trim() === "DigitalOcean"
      );
      if (title) title.textContent = "Choose model for DigitalOcean";
      if (subtitle && subtitle !== title) subtitle.textContent = "DigitalOcean";
    });

    const names = new Set(doAgents.map((agent) =>
      typeof agent.name === "string" ? agent.name.trim().toLowerCase() : ""
    ));
    const assignees = document.querySelector('[role="listbox"][aria-label="Assignees"]');
    if (assignees) {
      assignees.querySelectorAll('[role="option"]').forEach((option) => {
        const nameNode = Array.from(option.querySelectorAll("span")).find((span) =>
          String(span.className).indexOf("font-medium") !== -1
        );
        const name = nameNode ? nameNode.textContent.trim().toLowerCase() : "";
        if (!name || !names.has(name)) return;
        option.querySelectorAll("span").forEach((span) => {
          if (span.textContent.trim() === "OpenCode") span.textContent = "DigitalOcean";
        });
      });
    }

    if (viewingDoAgent()) {
      document.querySelectorAll("span").forEach((span) => {
        if (span.textContent.trim() !== "Adapter") return;
        const row = span.parentElement;
        if (!row) return;
        const value = row.querySelector("span.font-mono");
        if (value && value.textContent.trim() === "OpenCode") value.textContent = "DigitalOcean";
      });
      const heading = document.querySelector("h1");
      const header = heading && heading.parentElement;
      [header, header && header.parentElement].forEach((scope) => {
        if (!scope) return;
        scope.querySelectorAll("a, span").forEach((node) => {
          if (node.childElementCount === 0 && node.textContent.trim() === "OpenCode") {
            node.textContent = "DigitalOcean";
          }
        });
      });
    }

    // Agent list rows, the composer card under the agent name, and any other
    // short "OpenCode" label that sits next to a digitalocean/ model. Leave
    // the new-agent OpenCode tile and select options unchanged.
    document.querySelectorAll("a, span, p, dd, div").forEach((node) => {
      if (node.childElementCount !== 0 || node.textContent.trim() !== "OpenCode") return;
      if (node.closest("select, option, fieldset, [" + NEW_AGENT_MARK + "]")) return;
      const dialog = node.closest('[role="dialog"]');
      if (dialog && dialog.textContent.indexOf("Choose an adapter") !== -1) return;
      const named = node.closest("li, tr, [role='row'], [data-testid='composer-run-settings-view']");
      const agentName = named
        ? Array.from(named.querySelectorAll("span")).find((span) =>
          String(span.className).indexOf("font-medium") !== -1
        )
        : null;
      const knownAgent = agentName && names.has(agentName.textContent.trim().toLowerCase());
      if (!knownAgent && !labelSitsWithDigitalOceanModel(node)) return;
      node.textContent = "DigitalOcean";
    });
  };

  const labelSitsWithDigitalOceanModel = (node) => {
    let parent = node.parentElement;
    for (let depth = 0; depth < 6 && parent && parent !== document.body; depth += 1) {
      const text = parent.textContent || "";
      if (text.length > 500) return false;
      if (text.indexOf("digitalocean/") !== -1 || text.indexOf("DigitalOcean ·") !== -1) return true;
      parent = parent.parentElement;
    }
    return false;
  };

  const agentNameFromDialog = () => {
    if (draftName) return draftName;
    const nodes = document.querySelectorAll("p");
    for (let index = 0; index < nodes.length; index += 1) {
      const match = nodes[index].textContent.trim().match(/^How should (.+) work\?$/);
      if (match && match[1].trim()) return match[1].trim();
    }
    return "";
  };

  const hireNewAgent = async (button) => {
    if (newAgentBusy || !config) return;
    const name = agentNameFromDialog();
    if (!name) {
      status("Enter an agent name, then choose DigitalOcean.", true);
      return;
    }
    const companyId = await companyIdForPath();
    if (!companyId) {
      status("Could not find this organization.", true);
      return;
    }

    newAgentBusy = true;
    button.disabled = true;
    status("Creating your DigitalOcean agent…", false);
    try {
      const listed = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agents", {
        credentials: "include",
        headers: { Accept: "application/json" },
      });
      const agents = listed.ok ? await listed.json().catch(() => []) : [];
      const existing = Array.isArray(agents) ? agents : [];
      const leader = existing.find((agent) =>
        agent && agent.role === "ceo" && agent.status !== "terminated" && typeof agent.id === "string"
      );
      const hired = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agent-hires", {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          name: name,
          role: existing.length ? "general" : "ceo",
          reportsTo: leader ? leader.id : undefined,
          adapterType: "opencode_local",
          adapterConfig: {
            model: config.model,
            dangerouslySkipPermissions: true,
          },
          runtimeConfig: {},
        }),
      });
      if (!hired.ok) throw new Error(await errorMessage(hired));
      const hire = await hired.json();
      if (hire && hire.approval && typeof hire.approval.id === "string") {
        const approved = await fetch("/api/approvals/" + encodeURIComponent(hire.approval.id) + "/approve", {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({ decisionNote: "Approved during DigitalOcean agent setup." }),
        });
        if (!approved.ok) throw new Error(await errorMessage(approved));
      }
      const agent = hire && hire.agent ? hire.agent : hire;
      const agentId = agent && typeof agent.id === "string" ? agent.id : "";
      if (!agentId) throw new Error("DigitalOcean Inference connected, but no agent id was returned.");
      await waitForRunnableAgent(agentId, companyId, agent);
      const prefix = currentPrefix();
      window.location.assign(
        "/" + encodeURIComponent(prefix) + "/agents/" + encodeURIComponent(agentId)
      );
    } catch (error) {
      newAgentBusy = false;
      button.disabled = false;
      status(error instanceof Error ? error.message : "Could not create the DigitalOcean agent.", true);
    }
  };

  const paintNewAgent = () => {
    const title = Array.from(document.querySelectorAll("h2")).find((node) =>
      node.textContent.trim() === "Choose an adapter"
    );
    const dialog = title && title.closest('[role="dialog"]');
    if (!dialog) {
      newAgentSelected = false;
      return;
    }
    const fieldset = Array.from(dialog.querySelectorAll("fieldset")).find((node) => {
      const legend = node.querySelector("legend");
      return legend && legend.textContent.trim() === "Adapter";
    });
    const grid = fieldset && fieldset.querySelector("div");
    if (!grid) return;

    let tile = grid.querySelector("[" + NEW_AGENT_MARK + '="1"]');
    if (!tile) {
      const sample = Array.from(grid.querySelectorAll(":scope > label")).find((label) => {
        const name = label.querySelector("span");
        return name && name.textContent.trim() !== "DigitalOcean";
      });
      if (!sample) return;
      tile = sample.cloneNode(true);
      tile.setAttribute(NEW_AGENT_MARK, "1");
      const input = tile.querySelector("input");
      if (input) {
        input.type = "checkbox";
        input.checked = false;
        input.removeAttribute("name");
        input.value = "digitalocean";
      }
      const label = Array.from(tile.querySelectorAll("span")).find((span) =>
        String(span.className).indexOf("font-medium") !== -1
      );
      if (label) label.textContent = "DigitalOcean";
      const card = tile.querySelector("span");
      if (card) {
        const image = document.createElement("img");
        image.alt = "";
        image.width = 24;
        image.height = 24;
        image.src = FAVICON;
        image.style.width = "24px";
        image.style.height = "24px";
        image.style.objectFit = "contain";
        const existingIcon = card.querySelector("svg, img");
        if (existingIcon) existingIcon.replaceWith(image);
        else card.insertBefore(image, card.firstChild);
      }
      tile.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        newAgentSelected = true;
        paintNewAgent();
      });
      grid.appendChild(tile);
    }

    const card = tile.querySelector("span");
    if (card) {
      card.style.boxShadow = newAgentSelected ? "inset 0 0 0 1px currentColor" : "";
    }
    const check = tile.querySelector("svg");
    if (check) check.style.display = newAgentSelected ? "" : "none";

    grid.querySelectorAll(":scope > label").forEach((label) => {
      if (label.getAttribute(NEW_AGENT_MARK) === "1") return;
      const otherCard = label.querySelector("span");
      const otherCheck = label.querySelector("svg");
      if (newAgentSelected) {
        if (otherCard) otherCard.style.setProperty("border-color", "var(--border)", "important");
        if (otherCheck) otherCheck.style.display = "none";
      } else {
        if (otherCard) otherCard.style.removeProperty("border-color");
        if (otherCheck) otherCheck.style.removeProperty("display");
      }
    });

    const configure = Array.from(dialog.querySelectorAll("button")).find((button) =>
      button.textContent.indexOf("Configure agent") !== -1
    );
    if (configure && newAgentSelected) configure.disabled = false;
  };

  const scan = () => {
    if (!config) return;
    const group = document.querySelector('[role="radiogroup"][aria-label="Model source"]');
    if (group) paint(group);
    paintNewAgent();
    refreshDoAgents();
    relabelDigitalOcean();
  };

  const schedule = () => {
    if (scheduled) return;
    scheduled = true;
    window.requestAnimationFrame(() => {
      scheduled = false;
      scan();
    });
  };

  const start = () => {
    document.addEventListener("input", (event) => {
      const input = event.target;
      if (!input || input.tagName !== "INPUT" || !input.id) return;
      const label = document.querySelector('label[for="' + input.id + '"]');
      if (label && label.textContent.trim() === "Agent name") draftName = input.value.trim();
    });
    document.addEventListener("change", (event) => {
      const input = event.target;
      if (!input || input.name !== "new-agent-adapter") return;
      newAgentSelected = false;
    }, true);
    document.addEventListener("click", (event) => {
      if (!newAgentSelected || newAgentBusy) return;
      const target = event.target;
      const button = target && target.closest ? target.closest("button") : null;
      if (!button || button.textContent.indexOf("Configure agent") === -1) return;
      event.preventDefault();
      event.stopPropagation();
      void hireNewAgent(button);
    }, true);
    document.addEventListener("submit", (event) => {
      const form = event.target;
      if (!newAgentSelected || !form || !form.querySelector) return;
      if (!form.querySelector("[" + NEW_AGENT_MARK + '="1"]')) return;
      event.preventDefault();
      event.stopPropagation();
    }, true);
    scan();
    const observer = new MutationObserver(schedule);
    observer.observe(document.body, { childList: true, subtree: true });
  };

  fetch("/digitalocean-inference.json", { cache: "no-store", credentials: "same-origin" })
    .then((response) => (response.ok ? response.json() : null))
    .then((data) => {
      if (!data || data.enabled !== true || !isOpenCodeModel(data.model)) return;
      config = data;
      if (document.body) start();
      else document.addEventListener("DOMContentLoaded", start);
    })
    .catch(() => {});
})();
