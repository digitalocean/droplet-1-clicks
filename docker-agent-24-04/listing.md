# Docker Agent 1-Click Application

Deploy **Docker Agent** by Docker Engineering—an AI Agent Builder and Runtime that lets you create and run intelligent AI agents with specialized capabilities and tools. Build agent teams that collaborate to solve complex problems with ease.

## What is Docker Agent?

Docker Agent is Docker's AI agent framework (from the [docker/docker-agent](https://github.com/docker/docker-agent) project). It lets you create and run intelligent AI agents with specialized knowledge, tools, and capabilities—like building a team of virtual experts that work together to solve problems for you.

Built on modern AI technologies, Docker Agent offers:

- **Multi-agent architecture** – Create specialized agents for different domains
- **Rich tool ecosystem** – Agents can use external tools and APIs via the MCP protocol
- **Smart delegation** – Agents automatically route tasks to the most suitable specialist
- **YAML configuration** – Simple, declarative model and agent configuration
- **Advanced reasoning** – Built-in "think", "todo", and "memory" tools for complex problem-solving
- **Multiple AI providers** – Support for OpenAI, Anthropic, Google Gemini, DigitalOcean Inference (Gradient), and Docker Model Runner

## Key Features

- Create intelligent AI agents with specialized capabilities
- Build multi-agent teams that collaborate on complex tasks
- Use Model Context Protocol (MCP) tools for extended functionality
- Simple YAML-based configuration
- Support for both cloud-based and local AI models
- Push and pull agents from Docker Hub
- Built-in reasoning and memory capabilities
- Docker-based deployment for easy management

## System Requirements

Docker Agent is installed as a binary on Ubuntu 24.04 and requires Docker for containerized AI models and tools.

| Use Case | RAM | CPU |
|----------|-----|-----|
| Basic agents with cloud APIs | 1GB | 1 CPU |
| Local models (small) | 4GB | 2 CPU |
| Local models (medium) | 8GB | 4 CPU |
| Local models (large) | 16GB+ | 8 CPU+ |

**Note:** Using cloud AI providers (OpenAI, Anthropic, Google, DigitalOcean Gradient) requires minimal resources. Running local models via Docker Model Runner requires more resources depending on model size.

## Getting Started

### Quick Start

1. **Deploy the Droplet** – Choose this 1-Click App from the DigitalOcean Marketplace.
2. **SSH into your Droplet** – `ssh root@your-droplet-ip`
3. **Set your API key** – Export the variables your agent needs (OpenAI, Anthropic, Google, or **DigitalOcean Gradient** — see below).
4. **Run an agent** – Start with the bundled examples (including `gradient_agent.yaml` for Gradient).

### Setting Up API Keys

Set the environment variable for each provider your agent YAML uses. For **DigitalOcean Inference (Gradient)**, create a model access key in the [DigitalOcean Gen AI console](https://cloud.digitalocean.com/gen-ai):

```bash
# DigitalOcean Inference (Gradient)
export DO_GRADIENT_API_KEY=your_gradient_key_here

# OpenAI models (GPT-4, GPT-3.5, etc.)
export OPENAI_API_KEY=your_openai_key_here

# Anthropic models (Claude)
export ANTHROPIC_API_KEY=your_anthropic_key_here

# Google Gemini models
export GOOGLE_API_KEY=your_google_key_here
```

You only need API keys for the providers you use. Example one-liner for Gradient:

```bash
DO_GRADIENT_API_KEY=your_key docker-agent run /opt/docker-agent/examples/gradient_agent.yaml
```

For local models via Docker Model Runner, no cloud API key is required.

### Run Your First Agent

Try the included example agents (use the `docker-agent` CLI—Docker Agent’s command-line tool):

```bash
# DigitalOcean Inference / Gradient (requires DO_GRADIENT_API_KEY)
docker-agent run /opt/docker-agent/examples/gradient_agent.yaml

# OpenAI (requires OPENAI_API_KEY)
docker-agent run /opt/docker-agent/examples/basic_agent.yaml

# Docker Model Runner — local models (no cloud API key)
docker-agent run /opt/docker-agent/examples/dmr.yaml

# Other examples (check each YAML for provider / token_key)
docker-agent run /opt/docker-agent/examples/pirate.yaml
docker-agent run /opt/docker-agent/examples/pythonist.yaml
docker-agent run /opt/docker-agent/examples/todo.yaml
```

**DigitalOcean Inference (Gradient):** The image includes `gradient_agent.yaml`, configured with `base_url` `https://inference.do-ai.run/v1` and `token_key: DO_GRADIENT_API_KEY`. Use the `export` or one-liner above, then run that file with `docker-agent run`.

### Create Custom Agents

Use the interactive agent builder:

```bash
# Interactive mode—follow the prompts
docker-agent new

# Generate with a specific model
docker-agent new --model openai/gpt-4o-mini

# Generate with a local model via DMR
docker-agent new --model dmr/ai/gemma3:2B-Q4_0
```

### Using Docker Model Runner (DMR)

Docker Model Runner lets you run AI models locally without API keys:

1. **Enable DMR** in Docker Engine (may be enabled by default).
2. **Pull a model** – Docker can pull models when needed.
3. **Run agents** using the `dmr` provider in your configuration.

Example DMR configuration:

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

### Agent Store – Push and Pull Agents

Share agents via Docker Hub:

```bash
# Pull an agent from Docker Hub
docker-agent pull docker.io/username/my-agent:latest

# Push your agent to Docker Hub
docker-agent push ./my-agent.yaml docker.io/username/my-agent:latest

# Run an agent from Docker Hub
docker-agent run creek/pirate
```

## Configuration

### Basic Agent Configuration

Agents are configured with YAML. Minimal example:

```yaml
version: "2"

agents:
  root:
    model: openai/gpt-4o-mini
    description: A helpful AI assistant
    instruction: |
      You are a knowledgeable assistant that helps users with various tasks.
      Be helpful, accurate, and concise in your responses.

models:
  openai:
    provider: openai
    model: gpt-4o-mini
    max_tokens: 4096
```

### Multi-Agent Teams

Create specialized agents that work together:

```yaml
version: "2"

agents:
  root:
    model: coordinator
    description: Main coordinator agent
    instruction: |
      You coordinate tasks and delegate to specialized agents.
    sub_agents: ["researcher", "writer"]

  researcher:
    model: research-model
    description: Research specialist
    instruction: You research topics and gather information.

  writer:
    model: writing-model
    description: Writing specialist
    instruction: You create well-written content based on research.

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

### Adding Tools via MCP

Extend agents with Model Context Protocol tools:

```yaml
version: "2"

agents:
  root:
    model: assistant
    description: Assistant with web search capabilities
    instruction: You help users by searching the web when needed.
    toolsets:
      - type: mcp
        ref: docker:duckduckgo

models:
  assistant:
    provider: openai
    model: gpt-4o-mini
    max_tokens: 4096
```

## Common Commands

```bash
# View all available commands
docker-agent --help

# Run an agent
docker-agent run ./my-agent.yaml

# Create a new agent interactively
docker-agent new

# Build a Docker image for your agent
docker-agent build ./my-agent.yaml my-agent:latest

# Pull an agent from Docker Hub
docker-agent pull creek/pirate

# Push your agent to Docker Hub
docker-agent push ./my-agent.yaml username/my-agent:latest

# View agent readme
docker-agent readme ./my-agent.yaml
```

## Examples and Documentation

- **On-droplet:** `/opt/docker-agent/examples/` – Example configurations  
- **Quick reference:** `/opt/docker-agent/README.txt`  
- **GitHub:** [docker/docker-agent – examples](https://github.com/docker/docker-agent/tree/main/examples)

Example categories: basic single-agent configs, advanced agents with tools, and multi-agent teams.

## Use Cases

- **Code assistance** – Agents for different languages and frameworks
- **Research and analysis** – Search, analyze, and summarize information
- **Content creation** – Multi-agent teams for research, writing, and editing
- **Task automation** – Agents with filesystem, git, and system tools
- **Custom workflows** – Specialized agent teams for your use cases

## Support and Resources

- **GitHub:** [github.com/docker/docker-agent](https://github.com/docker/docker-agent)
- **Usage:** [USAGE.md](https://github.com/docker/docker-agent/blob/main/docs/USAGE.md)
- **Contributing:** [CONTRIBUTING.md](https://github.com/docker/docker-agent/blob/main/docs/CONTRIBUTING.md)
- **DigitalOcean Community:** https://www.digitalocean.com/community
- **Docker Community Slack:** https://dockercommunity.slack.com/archives/C09DASHHRU4

## Post-Deployment

After deployment you have:

- Docker Agent CLI (`docker-agent`) at `/usr/local/bin/docker-agent`
- Docker installed for containerized models and tools
- Example configurations in `/opt/docker-agent/examples/`
- Quick reference at `/opt/docker-agent/README.txt`

### Next Steps

1. Set your API keys (for example `DO_GRADIENT_API_KEY` for Gradient, `OPENAI_API_KEY` for OpenAI).
2. Run the example agents (try `gradient_agent.yaml` for DigitalOcean Inference).
3. Create a custom agent with `docker-agent new`.
4. Explore MCP tools and multi-agent setups.

### Important Notes

- **API keys** – Store in environment variables; avoid committing them.
- **Docker Model Runner** – Ensure enough RAM for local model inference.
- **MCP tools** – Some may need extra setup (e.g., npm, cargo).
- **Networking** – Docker Agent is CLI-based; no open ports required for basic use.
- **Updates** – Check version with `docker-agent --version`; update by installing newer releases from [docker/docker-agent releases](https://github.com/docker/docker-agent/releases).

Ideal for developers, researchers, and teams who want to use AI agents for complex tasks and automation.
