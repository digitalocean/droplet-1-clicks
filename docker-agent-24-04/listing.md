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
- **Multiple AI providers** – Support for OpenAI, Anthropic, Google Gemini, and Docker Model Runner

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

**Note:** Using cloud AI providers (OpenAI, Anthropic, Google) requires minimal resources. Running local models via Docker Model Runner requires more resources depending on model size.

## Getting Started

### Quick Start

1. **Deploy the Droplet** – Choose this 1-Click App from the DigitalOcean Marketplace.
2. **SSH into your Droplet** – `ssh root@your-droplet-ip`
3. **Set your API key** – Configure access to your preferred AI provider (see below).
4. **Run an agent** – Use the included examples or create your own.

### Setting Up API Keys

Set the environment variable for the AI provider you plan to use:

```bash
# For OpenAI models (GPT-4, GPT-3.5, etc.)
export OPENAI_API_KEY=your_openai_key_here

# For Anthropic models (Claude)
export ANTHROPIC_API_KEY=your_anthropic_key_here

# For Google Gemini models
export GOOGLE_API_KEY=your_google_key_here
```

You only need API keys for the providers you use. For local models via Docker Model Runner, no API key is required.

### Run Your First Agent

Try the included example agents (use the `cagent` CLI—Docker Agent’s command-line tool):

```bash
# Run a basic agent (requires OPENAI_API_KEY)
cagent run /opt/docker-agent/examples/basic_agent.yaml

# Run a local agent using Docker Model Runner (no API key needed)
cagent run /opt/docker-agent/examples/dmr.yaml

# Other examples
cagent run /opt/docker-agent/examples/pirate.yaml      # Fun pirate assistant
cagent run /opt/docker-agent/examples/pythonist.yaml  # Python programming expert
cagent run /opt/docker-agent/examples/todo.yaml       # Task manager with memory
```

### Create Custom Agents

Use the interactive agent builder:

```bash
# Interactive mode—follow the prompts
cagent new

# Generate with a specific model
cagent new --model openai/gpt-4o-mini

# Generate with a local model via DMR
cagent new --model dmr/ai/gemma3:2B-Q4_0
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
cagent pull docker.io/username/my-agent:latest

# Push your agent to Docker Hub
cagent push ./my-agent.yaml docker.io/username/my-agent:latest

# Run an agent from Docker Hub
cagent run creek/pirate
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
cagent --help

# Run an agent
cagent run ./my-agent.yaml

# Create a new agent interactively
cagent new

# Build a Docker image for your agent
cagent build ./my-agent.yaml my-agent:latest

# Pull an agent from Docker Hub
cagent pull creek/pirate

# Push your agent to Docker Hub
cagent push ./my-agent.yaml username/my-agent:latest

# View agent readme
cagent readme ./my-agent.yaml
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

- Docker Agent CLI (`cagent`) at `/usr/local/bin/cagent`
- Docker installed for containerized models and tools
- Example configurations in `/opt/docker-agent/examples/`
- Quick reference at `/opt/docker-agent/README.txt`

### Next Steps

1. Set your preferred AI provider API key.
2. Run the example agents.
3. Create a custom agent with `cagent new`.
4. Explore MCP tools and multi-agent setups.

### Important Notes

- **API keys** – Store in environment variables; avoid committing them.
- **Docker Model Runner** – Ensure enough RAM for local model inference.
- **MCP tools** – Some may need extra setup (e.g., npm, cargo).
- **Networking** – Docker Agent is CLI-based; no open ports required for basic use.
- **Updates** – Check version with `cagent --version`; update by installing newer releases from [docker/docker-agent releases](https://github.com/docker/docker-agent/releases).

Ideal for developers, researchers, and teams who want to use AI agents for complex tasks and automation.
