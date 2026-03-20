# Docker Agent 1-Click Application

Deploy **Docker Agent** by Docker Engineering—an AI agent builder and runtime that orchestrates agents with specialized tools and capabilities. Build agent teams that collaborate on complex tasks using YAML configuration, MCP tools, and Docker.

**CLI note:** Releases ship the command-line binary as `cagent`. All examples below use that command; run `cagent --help` on the Droplet for the full command reference.

## What is Docker Agent?

Docker Agent is Docker’s open source stack for defining, running, and sharing AI agents. You describe agents and models in YAML, run them locally or with cloud providers, and extend them with Model Context Protocol (MCP) tools.

Docker Agent offers:

- **Multi-agent architecture** — Specialized agents for different domains
- **Rich tool ecosystem** — MCP tools and container-backed capabilities
- **Smart delegation** — Route work to the right specialist agents
- **YAML configuration** — Declarative models and agent definitions
- **Reasoning helpers** — Built-in patterns for planning, memory, and tasks
- **Multiple AI providers** — OpenAI, Anthropic, Google Gemini, Docker Model Runner, and more

## Key Features

- Create and run intelligent agents from YAML
- Multi-agent workflows with delegation
- MCP tool integration
- Cloud APIs or local models (e.g. via Docker Model Runner)
- Push and pull agents with Docker Hub
- Docker-based execution for models and tools

## System Requirements

The `cagent` CLI is installed on Ubuntu 24.04. Docker is required for containerized models, tools, and typical workflows.

| Use Case | RAM | CPU |
|----------|-----|-----|
| Basic agents with cloud APIs | 1GB | 1 CPU |
| Local models (small) | 4GB | 2 CPU |
| Local models (medium) | 8GB | 4 CPU |
| Local models (large) | 16GB+ | 8 CPU+ |

**Note:** Cloud providers need only light resources. Local inference via Docker Model Runner scales with model size.

## Getting Started

### Quick start

1. **Deploy the Droplet** — Choose this 1-Click from the DigitalOcean Marketplace.
2. **SSH in** — `ssh root@your-droplet-ip`
3. **Set API keys** — For any cloud providers you use (see below).
4. **Run an agent** — Start from bundled examples or run `cagent new`.

### Setting up API keys

```bash
# OpenAI (GPT family, etc.)
export OPENAI_API_KEY=your_openai_key_here

# Anthropic (Claude)
export ANTHROPIC_API_KEY=your_anthropic_key_here

# Google Gemini
export GOOGLE_API_KEY=your_google_key_here
```

You only need keys for providers you use. Docker Model Runner workflows can avoid cloud keys when models run locally.

### Running your first agent

```bash
# Basic agent (needs OPENAI_API_KEY)
cagent run /opt/cagent/examples/basic_agent.yaml

# Local-style agent via Docker Model Runner
cagent run /opt/cagent/examples/dmr.yaml

# More examples on the image
cagent run /opt/cagent/examples/pirate.yaml
cagent run /opt/cagent/examples/pythonist.yaml
cagent run /opt/cagent/examples/todo.yaml
```

### Creating custom agents

```bash
cagent new
cagent new --model openai/gpt-4o-mini
cagent new --model dmr/ai/gemma3:2B-Q4_0
```

### Docker Model Runner (DMR)

DMR runs models locally without cloud API keys when configured appropriately:

1. Ensure DMR is available in your Docker setup.
2. Pull or run models as needed for your agent YAML.
3. Reference the `dmr` provider in your configuration.

Example snippet:

```yaml
version: "2"

agents:
  root:
    model: local-model
    description: A helpful AI assistant
    instruction: You are a knowledgeable assistant.

models:
  local-model:
    provider: dmr
    model: ai/gemma3:2B-Q4_0
    max_tokens: 8192
```

### Agent registry — push and pull

```bash
cagent pull docker.io/username/my-agent:latest
cagent push ./my-agent.yaml docker.io/username/my-agent:latest
cagent run creek/pirate
```

## Configuration examples

### Minimal single agent

```yaml
version: "2"

agents:
  root:
    model: openai/gpt-4o-mini
    description: A helpful AI assistant
    instruction: |
      You are a knowledgeable assistant. Be clear and concise.

models:
  openai:
    provider: openai
    model: gpt-4o-mini
    max_tokens: 4096
```

### Multi-agent team (illustrative)

```yaml
version: "2"

agents:
  root:
    model: coordinator
    description: Main coordinator
    instruction: You coordinate and delegate to specialists.
    sub_agents: ["researcher", "writer"]

  researcher:
    model: research-model
    description: Research specialist
    instruction: You research and summarize sources.

  writer:
    model: writing-model
    description: Writing specialist
    instruction: You turn research into polished text.

models:
  coordinator:
    provider: anthropic
    model: claude-sonnet-4-0
  research-model:
    provider: openai
    model: gpt-4o
  writing-model:
    provider: anthropic
    model: claude-sonnet-4-0
```

### MCP tools

```yaml
version: "2"

agents:
  root:
    model: assistant
    description: Assistant with extra tools
    instruction: Help the user; use tools when useful.
    toolsets:
      - type: mcp
        ref: docker:duckduckgo

models:
  assistant:
    provider: openai
    model: gpt-4o-mini
    max_tokens: 4096
```

## Common commands

```bash
cagent --help
cagent run ./my-agent.yaml
cagent new
cagent build ./my-agent.yaml my-agent:latest
cagent pull creek/pirate
cagent push ./my-agent.yaml username/my-agent:latest
cagent readme ./my-agent.yaml
```

## Examples and documentation

- `/opt/cagent/examples/` — Examples copied onto the image at build time
- `/opt/cagent/README.txt` — Short reference after SSH
- [Examples on GitHub](https://github.com/docker/docker-agent/tree/main/examples)

## Support and resources

- **Repository:** [github.com/docker/docker-agent](https://github.com/docker/docker-agent)
- **Usage:** [docs/USAGE.md](https://github.com/docker/docker-agent/blob/main/docs/USAGE.md)
- **Contributing:** [docs/CONTRIBUTING.md](https://github.com/docker/docker-agent/blob/main/docs/CONTRIBUTING.md)
- **DigitalOcean Community:** [digitalocean.com/community](https://www.digitalocean.com/community)
- **Docker Community Slack:** [dockercommunity.slack.com](https://dockercommunity.slack.com/) (see project README for channels)

## Post-deployment notes

After deploy you get:

- `cagent` at `/usr/local/bin/cagent`
- Docker for models and tools
- Examples under `/opt/cagent/examples/`
- Quick reference at `/opt/cagent/README.txt`

### Next steps

1. Configure provider API keys if you use cloud models.
2. Run an example agent from `/opt/cagent/examples/`.
3. Run `cagent new` to scaffold your own YAML.
4. Explore MCP tools and multi-agent patterns in the upstream repo.

### Operational notes

- Store secrets in environment variables or a secrets manager—not in world-readable files.
- Local models need enough RAM/CPU for the chosen weights.
- Some MCP servers need extra runtimes (e.g. Node, Rust) on the host or in containers.
- The CLI is local; no inbound ports are required for basic usage.
- Check version with `cagent --version`; upgrade by installing a newer release from [GitHub Releases](https://github.com/docker/docker-agent/releases).

Ideal for developers and teams building agentic workflows on top of Docker and the wider AI tooling ecosystem.
