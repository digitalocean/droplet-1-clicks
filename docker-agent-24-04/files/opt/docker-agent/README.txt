Welcome to Docker Agent on DigitalOcean!

Docker Agent (docker/docker-agent) is an AI agent builder and runtime. Use the
docker-agent CLI to run and manage agents from YAML.

================================================================================
1. API KEYS
================================================================================

Export only what your YAML needs. When using several providers, use this order:

  (1) OPENAI_API_KEY
  (2) ANTHROPIC_API_KEY
  (3) GOOGLE_API_KEY
  (4) DO_GRADIENT_API_KEY

Where to get keys:

  OpenAI       https://platform.openai.com/api-keys
  Anthropic    https://console.anthropic.com/
  Google       https://aistudio.google.com/apikey
  Gradient     https://cloud.digitalocean.com/gen-ai

Example:

  export OPENAI_API_KEY=your_api_key_here
  export ANTHROPIC_API_KEY=your_api_key_here
  export GOOGLE_API_KEY=your_api_key_here
  export DO_GRADIENT_API_KEY=your_gradient_key_here

First SSH: optional prompts save keys to /root/.bashrc (same order as above:
OpenAI, then Anthropic, then Google, then Gradient). Then:

  source /root/.bashrc

================================================================================
2. RUN AGENTS
================================================================================

Your shell must have the same variable names your YAML uses in token_key.

Bundled examples
----------------
  OPENAI_API_KEY:
    docker-agent run /opt/docker-agent/examples/basic_agent.yaml

  DO_GRADIENT_API_KEY:
    docker-agent run /opt/docker-agent/examples/gradient_agent.yaml

Anthropic / Google (no dedicated bundled file)
----------------------------------------------
  Use YAML whose models section uses token_key ANTHROPIC_API_KEY or
  GOOGLE_API_KEY. Start from:

    docker-agent new --model anthropic/...
    docker-agent new --model google/...

  Then:

    docker-agent run /path/to/your-agent.yaml

Local models (Docker Model Runner)
----------------------------------
  No cloud API key:

    docker-agent run /opt/docker-agent/examples/dmr.yaml

More samples (check each file for provider / token_key)
-------------------------------------------------------
    docker-agent run /opt/docker-agent/examples/pirate.yaml
    docker-agent run /opt/docker-agent/examples/pythonist.yaml
    docker-agent run /opt/docker-agent/examples/todo.yaml

One line per provider (same order as keys)
------------------------------------------
  OPENAI_API_KEY=k docker-agent run /opt/docker-agent/examples/basic_agent.yaml
  ANTHROPIC_API_KEY=k docker-agent run ./my-agent.yaml
  GOOGLE_API_KEY=k docker-agent run ./my-agent.yaml
  DO_GRADIENT_API_KEY=k docker-agent run /opt/docker-agent/examples/gradient_agent.yaml

CLI help:

  docker-agent --help
  docker-agent run --help

================================================================================
3. CREATE AGENTS
================================================================================

  docker-agent new
  docker-agent new --model openai/gpt-4o-mini

================================================================================
4. DOCKER HUB
================================================================================

  docker-agent run creek/pirate

================================================================================
USEFUL COMMANDS
================================================================================

  docker-agent --help
  docker-agent pull docker.io/username/my-agent:latest
  docker-agent push ./my-agent.yaml docker.io/username/my-agent:latest
  docker-agent build ./my-agent.yaml my-agent:latest

================================================================================
DOCUMENTATION
================================================================================

  Project:     https://github.com/docker/docker-agent
  Usage:       https://github.com/docker/docker-agent/blob/main/docs/USAGE.md
  Examples:    https://github.com/docker/docker-agent/tree/main/examples

================================================================================
NOTES
================================================================================

  - DMR runs local models without cloud API keys.
  - Example YAML lives in /opt/docker-agent/examples/
  - Agents are YAML: models, tools, instructions.

================================================================================
CLOUD PROVIDER CHEAT SHEET (token_key must match your export)
================================================================================

  OPENAI_API_KEY        basic_agent.yaml (bundled)
  ANTHROPIC_API_KEY     your YAML or docker-agent new --model anthropic/...
  GOOGLE_API_KEY        your YAML or docker-agent new --model google/...
  DO_GRADIENT_API_KEY   gradient_agent.yaml (bundled, inference.do-ai.run)

Gradient sample models block:

  agents:
    root:
      model: do_gradient
      instruction: You are a helpful assistant.
  models:
    do_gradient:
      provider: openai
      model: anthropic-claude-4.5-sonnet
      base_url: https://inference.do-ai.run/v1
      token_key: DO_GRADIENT_API_KEY

Support: https://github.com/docker/docker-agent
