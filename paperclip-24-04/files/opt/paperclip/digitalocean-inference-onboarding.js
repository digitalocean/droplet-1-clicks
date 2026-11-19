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
  // One automatic host-compat repair per agent per page session.
  const repairedAgents = new Set();

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

  const retryAgentLifecycle = async (agentId, companyId) => {
    const response = await fetch(
      "/api/agents/" + encodeURIComponent(agentId) + "/lifecycle/retry?companyId=" + encodeURIComponent(companyId),
      {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: "{}",
      },
    );
    if (!response.ok) throw new Error(await errorMessage(response));
    return response.json().catch(() => null);
  };

  // Host PATH for the paperclip service includes /usr/local/bin, but the
  // verification hello probe is more reliable with an absolute command. Force
  // the classic local adapter so Paperclip Runner does not skip the host CLI.
  const digitalOceanAdapterConfig = (existing) => {
    const base = existing && typeof existing === "object" ? { ...existing } : {};
    const model = config && typeof config.model === "string" && config.model
      ? config.model
      : (typeof base.model === "string" ? base.model : "");
    return {
      ...base,
      model: model,
      command: "/usr/local/bin/opencode",
      // Unattended Marketplace agents run as the unprivileged `paperclip`
      // user. Without this, OpenCode blocks on interactive permission prompts
      // and verification / heartbeats hang.
      dangerouslySkipPermissions: true,
    };
  };

  const canHireDigitalOcean = () =>
    Boolean(config && config.enabled === true && isOpenCodeModel(config.model));

  const fetchAgent = async (agentId, companyId) => {
    const listed = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agents", {
      credentials: "include",
      headers: { Accept: "application/json" },
    });
    if (!listed.ok) return null;
    const agents = await listed.json().catch(() => []);
    if (!Array.isArray(agents)) return null;
    return agents.find((agent) => agent && agent.id === agentId) || null;
  };

  const agentIsReady = (agent) => {
    if (!agent) return false;
    const lifecycle = typeof agent.lifecycleState === "string" ? agent.lifecycleState : "";
    const legacy = typeof agent.status === "string" ? agent.status : "";
    if (lifecycle === "ready" || lifecycle === "running" || lifecycle === "idle") return true;
    // Compatibility status "active"/"running" without a failed lifecycle.
    if (!lifecycle && (legacy === "active" || legacy === "running" || legacy === "idle")) return true;
    return false;
  };

  const agentNeedsResume = (agent) => {
    if (!agent) return false;
    const lifecycle = typeof agent.lifecycleState === "string" ? agent.lifecycleState : "";
    const legacy = typeof agent.status === "string" ? agent.status : "";
    return lifecycle === "paused" || (!lifecycle && legacy === "paused");
  };

  const agentVerificationFailed = (agent) => {
    if (!agent) return false;
    const lifecycle = typeof agent.lifecycleState === "string" ? agent.lifecycleState.toLowerCase() : "";
    const detail = [
      agent.lifecycleError,
      agent.lastError,
      agent.statusMessage,
      agent.verificationError,
    ].filter((value) => typeof value === "string").join(" ").toLowerCase();
    if (lifecycle.indexOf("fail") !== -1 || lifecycle === "error") return true;
    if (detail.indexOf("verification") !== -1 && detail.indexOf("fail") !== -1) return true;
    if (detail.indexOf("execution configuration") !== -1) return true;
    return false;
  };

  const agentNeedsHostCompatRepair = (agent) => {
    if (!agent || agent.adapterType !== "opencode_local") return false;
    const adapter = agent.adapterConfig && typeof agent.adapterConfig === "object"
      ? agent.adapterConfig
      : {};
    const model = typeof adapter.model === "string" ? adapter.model : "";
    if (model.indexOf("digitalocean/") !== 0) return false;
    const command = typeof adapter.command === "string" ? adapter.command.trim() : "";
    // Missing absolute command is the pre-fix hire shape. Do not treat
    // "paused while preparing/verifying" alone as repair — that is normal.
    if (command !== "/usr/local/bin/opencode") return true;
    return agentVerificationFailed(agent);
  };

  // Older images hired DO agents without an absolute opencode path. After the
  // host apply-inference fix, patch adapterConfig and retry verification so
  // operators do not have to click Retry now by hand.
  const repairDigitalOceanAgent = async (agent, companyId) => {
    if (!agent || typeof agent.id !== "string" || !companyId) return agent;
    if (repairedAgents.has(agent.id) || !agentNeedsHostCompatRepair(agent)) return agent;
    repairedAgents.add(agent.id);
    const patched = await fetch(
      "/api/agents/" + encodeURIComponent(agent.id) + "?companyId=" + encodeURIComponent(companyId),
      {
        method: "PATCH",
        credentials: "include",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          runner: "legacy",
          adapterConfig: digitalOceanAdapterConfig(agent.adapterConfig),
        }),
      },
    );
    if (!patched.ok) throw new Error(await errorMessage(patched));
    const updated = await patched.json().catch(() => agent);
    try {
      await retryAgentLifecycle(agent.id, companyId);
    } catch {
      // Retry is a no-op when setup already finished; resume may still apply.
    }
    if (agentNeedsResume(updated) || agentNeedsResume(agent)) {
      try {
        await resumeAgent(agent.id, companyId);
      } catch {
        // Resume can 409 while verification is still running.
      }
    }
    return (await fetchAgent(agent.id, companyId)) || updated || agent;
  };

  const waitForRunnableAgent = async (agentId, companyId, initialAgent) => {
    // New hires enter preparing/verifying asynchronously. Poll until ready.
    // A failed hello probe leaves the agent paused (Live + paused in the UI)
    // until Configuration → Run test / Retry now succeeds. Auto-repair once
    // for agents hired before absolute command + host OpenCode config landed.
    status("Verifying your DigitalOcean agent…", false);
    let agent = initialAgent || null;
    let resumed = false;
    let retried = false;
    const deadline = Date.now() + 120000;
    while (Date.now() < deadline) {
      agent = (await fetchAgent(agentId, companyId)) || agent;
      if (agentIsReady(agent)) return;
      if (!retried && (agentVerificationFailed(agent) || agentNeedsHostCompatRepair(agent))) {
        try {
          agent = await repairDigitalOceanAgent(agent, companyId);
          retried = true;
        } catch {
          retried = true;
        }
      }
      if (retried && agentVerificationFailed(agent)) {
        throw new Error(
          "DigitalOcean agent verification failed. On the Droplet run: sudo /opt/ensure-paperclip-opencode.sh && sudo /opt/apply-inference-from-env.sh && sudo systemctl daemon-reload && sudo systemctl restart paperclip — then open the agent and click Retry now.",
        );
      }
      if (!resumed && agentNeedsResume(agent)) {
        try {
          await resumeAgent(agentId, companyId);
          resumed = true;
        } catch {
          // Resume is invalid while still verifying; keep polling.
        }
      }
      await new Promise((resolve) => window.setTimeout(resolve, 2000));
    }
    if (agentNeedsResume(agent) || agentVerificationFailed(agent)) {
      throw new Error(
        "DigitalOcean agent stayed paused (verification did not finish). Fix OpenCode/Inference on the host, then click Retry now on the agent page.",
      );
    }
  };

  const connect = async (button) => {
    if (busy || !canHireDigitalOcean()) return;
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
      if (agentId && selectedAgent) {
        try {
          selectedAgent = await repairDigitalOceanAgent(selectedAgent, companyId);
        } catch {
          // waitForRunnableAgent will surface a lasting verification failure.
        }
      }
      if (!agentId) {
        const hired = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agent-hires", {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({
            name: name,
            role: role,
            adapterType: "opencode_local",
            runner: "legacy",
            adapterConfig: digitalOceanAdapterConfig(),
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
      // Older builds used "API". Current UI uses "API key" and can show
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
      const matched = agents.filter((agent) =>
        agent &&
        agent.adapterType === "opencode_local" &&
        agent.adapterConfig &&
        typeof agent.adapterConfig.model === "string" &&
        agent.adapterConfig.model.indexOf("digitalocean/") === 0 &&
        typeof agent.id === "string"
      );
      doAgents = matched;
      relabelDigitalOcean();
      for (const agent of matched) {
        if (!agentNeedsHostCompatRepair(agent) || repairedAgents.has(agent.id)) continue;
        try {
          await repairDigitalOceanAgent(agent, companyId);
        } catch {
          // Leave the agent as-is; listing.md covers manual Retry now.
        }
      }
      if (window.location.pathname !== path) return;
      const refreshed = await fetch("/api/companies/" + encodeURIComponent(companyId) + "/agents", {
        credentials: "include",
        headers: { Accept: "application/json" },
      });
      if (!refreshed.ok || window.location.pathname !== path) return;
      const again = await refreshed.json().catch(() => []);
      if (!Array.isArray(again) || window.location.pathname !== path) return;
      doAgents = again.filter((agent) =>
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
      // Agent header often renders "OpenCode • <name>" as separate or combined nodes.
      const heading = document.querySelector("h1");
      const scopes = [document.querySelector("main"), heading && heading.parentElement, heading && heading.parentElement && heading.parentElement.parentElement];
      scopes.forEach((scope) => {
        if (!scope) return;
        scope.querySelectorAll("a, span, p, div").forEach((node) => {
          if (node.childElementCount !== 0) return;
          const text = node.textContent.trim();
          if (text === "OpenCode") {
            node.textContent = "DigitalOcean";
            return;
          }
          if (text.indexOf("OpenCode •") === 0) {
            node.textContent = text.replace(/^OpenCode/, "DigitalOcean");
          }
        });
      });
    }

    // Agent list rows, the composer card under the agent name, and any other
    // short "OpenCode" label that sits next to a digitalocean/ model. Leave
    // the new-agent OpenCode tile and select options unchanged.
    document.querySelectorAll("a, span, p, dd, div").forEach((node) => {
      if (node.childElementCount !== 0) return;
      const text = node.textContent.trim();
      if (text !== "OpenCode" && text.indexOf("OpenCode •") !== 0) return;
      if (node.closest("select, option, fieldset, [" + NEW_AGENT_MARK + "]")) return;
      const dialog = node.closest('[role="dialog"]');
      if (dialog && dialog.textContent.indexOf("Choose an adapter") !== -1) return;
      const named = node.closest("li, tr, [role='row'], [data-testid='composer-run-settings-view'], header, main");
      const agentName = named
        ? Array.from(named.querySelectorAll("span")).find((span) =>
          String(span.className).indexOf("font-medium") !== -1
        )
        : null;
      const knownAgent = agentName && names.has(agentName.textContent.trim().toLowerCase());
      if (!knownAgent && !viewingDoAgent() && !labelSitsWithDigitalOceanModel(node)) return;
      node.textContent = text === "OpenCode" ? "DigitalOcean" : text.replace(/^OpenCode/, "DigitalOcean");
    });
    relabelAgentsTable();
  };

  const labelSitsWithDigitalOceanModel = (node) => {
    let parent = node.parentElement;
    for (let depth = 0; depth < 8 && parent && parent !== document.body; depth += 1) {
      const text = parent.textContent || "";
      // Agents table rows can be long; still treat digitalocean/ as a DO agent.
      if (text.indexOf("digitalocean/") !== -1 || text.indexOf("DigitalOcean ·") !== -1) return true;
      parent = parent.parentElement;
    }
    return false;
  };

  // Agents list Harness column shows the adapter name ("OpenCode") beside the
  // Default model column (digitalocean/...). Relabel those rows explicitly.
  const relabelAgentsTable = () => {
    document.querySelectorAll("table tbody tr, [role='row']").forEach((row) => {
      const text = row.textContent || "";
      if (text.indexOf("digitalocean/") === -1 && text.indexOf("DigitalOcean ·") === -1) return;
      row.querySelectorAll("a, span, p, td, div").forEach((node) => {
        if (node.childElementCount !== 0) return;
        if (node.textContent.trim() === "OpenCode") node.textContent = "DigitalOcean";
      });
    });
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
    if (newAgentBusy || !canHireDigitalOcean()) return;
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
          runner: "legacy",
          adapterConfig: digitalOceanAdapterConfig(),
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
    // Onboarding tiles need a configured DO model; list/header relabeling should
    // still run whenever digitalocean/ agents are visible.
    if (config && config.enabled === true && isOpenCodeModel(config.model)) {
      const group = document.querySelector('[role="radiogroup"][aria-label="Model source"]');
      if (group) paint(group);
      paintNewAgent();
    }
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
      config = data && typeof data === "object" ? data : { enabled: false, model: "" };
      // Always start: agents list / headers still need OpenCode → DigitalOcean
      // relabeling even when the onboarding tile is hidden.
      if (document.body) start();
      else document.addEventListener("DOMContentLoaded", start);
    })
    .catch(() => {
      config = { enabled: false, model: "" };
      if (document.body) start();
      else document.addEventListener("DOMContentLoaded", start);
    });
})();
