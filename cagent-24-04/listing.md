# cagent 1-Click Application

Deploy cagent by Docker, a powerful multi-agent AI runtime that orchestrates AI agents with specialized capabilities and tools. Build intelligent agent teams that collaborate to solve complex problems with ease.

## What is cagent?

cagent is Docker's cutting-edge AI agent framework that lets you create and run intelligent AI agents with specialized knowledge, tools, and capabilities. Think of it as building a team of virtual experts that work together to solve problems for you.

Built on modern AI technologies, cagent offers:

- **Multi-agent architecture** - Create specialized agents for different domains
- **Rich tool ecosystem** - Agents can use external tools and APIs via the MCP protocol
- **Smart delegation** - Agents automatically route tasks to the most suitable specialist
- **YAML configuration** - Simple, declarative model and agent configuration
- **Advanced reasoning** - Built-in "think", "todo" and "memory" tools for complex problem-solving
- **Multiple AI providers** - Support for OpenAI, Anthropic, Google Gemini, and Docker Model Runner

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

cagent is installed as a binary on Ubuntu 24.04 and requires Docker for containerized AI models and tools.

| Use Case | RAM | CPU |
|----------|-----|-----|
| Basic agents with cloud APIs | 1GB | 1CPU |
| Local models (small) | 4GB | 2CPU |
| Local models (medium) | 8GB | 4CPU |
| Local models (large) | 16GB+ | 8CPU+ |

**Note**: Using cloud AI providers (OpenAI, Anthropic, Google) requires minimal resources. Running local models via Docker Model Runner requires more resources depending on model size.

## Getting Started

### Quick Start

1. **Deploy the Droplet** - Select this 1-Click App from the DigitalOcean Marketplace
2. **SSH into your Droplet** - `ssh root@your-droplet-ip`
3. **Set your API key** - Configure access to your preferred AI provider
4. **Run an agent** - Start with example configurations or create your own

### Setting Up API Keys

Based on the AI models you plan to use, set the corresponding provider API key:

```bash
# For OpenAI models (GPT-4, GPT-3.5, etc.)
export OPENAI_API_KEY=your_openai_key_here

# For Anthropic models (Claude)
export ANTHROPIC_API_KEY=your_anthropic_key_here

# For Google Gemini models
export GOOGLE_API_KEY=your_google_key_here
```

**Note**: You only need API keys for the providers you intend to use. For local models via Docker Model Runner, no API key is required.

### Running Your First Agent

Try the included example agents:

```bash
# Run a basic agent (requires OPENAI_API_KEY)
cagent run /opt/cagent/examples/basic_agent.yaml

# Run a local agent using Docker Model Runner (no API key needed)
cagent run /opt/cagent/examples/dmr.yaml

# Try other examples
cagent run /opt/cagent/examples/pirate.yaml      # Fun pirate assistant
cagent run /opt/cagent/examples/pythonist.yaml   # Python programming expert
cagent run /opt/cagent/examples/todo.yaml        # Task manager with memory
```

### Creating Custom Agents

Use the interactive agent builder:

```bash
# Interactive mode - follow the prompts
cagent new

# Generate with a specific model
cagent new --model openai/gpt-4o-mini

# Generate with a local model via DMR
cagent new --model dmr/ai/gemma3:2B-Q4_0
```

### Using Docker Model Runner (DMR)

Docker Model Runner allows you to run AI models locally without API keys:

1. **Enable DMR** in Docker Engine (may be enabled by default)
2. **Pull a model**: Docker will automatically pull models when needed
3. **Run agents** using the `dmr` provider in your configuration

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

### Agent Store - Push and Pull Agents

Share your agents via Docker Hub:

```bash
# Pull an agent from Docker Hub
cagent pull docker.io/username/my-agent:latest

# Push your agent to Docker Hub
cagent push ./my-agent.yaml docker.io/username/my-agent:latest

# Run an agent directly from Docker Hub
cagent run creek/pirate
```

## Configuration

### Basic Agent Configuration

Agents are configured using YAML files. Here's a minimal example:

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
    instruction: |
      You research topics and gather information.
  
  writer:
    model: writing-model
    description: Writing specialist
    instruction: |
      You create well-written content based on research.

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

Extend agent capabilities with Model Context Protocol tools:

```yaml
version: "2"

agents:
  root:
    model: assistant
    description: Assistant with web search capabilities
    instruction: You help users by searching the web when needed.
    toolsets:
      - type: mcp
        ref: docker:duckduckgo  # Web search via containerized MCP server

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

Example agent configurations are available in:
- `/opt/cagent/examples/` - Local example configurations
- `/opt/cagent/README.txt` - Quick reference guide
- [GitHub Examples](https://github.com/docker/cagent/tree/main/examples) - Comprehensive examples

Categories of examples:
- **Basic**: Simple single-agent configurations
- **Advanced**: Agents with specialized tools and capabilities  
- **Multi-agent**: Agent teams that collaborate on complex tasks

## Use Cases

- **Code Assistance**: Specialized agents for different programming languages
- **Research and Analysis**: Agents that search, analyze, and summarize information
- **Content Creation**: Multi-agent teams for research, writing, and editing
- **Task Automation**: Agents with tools for filesystem, git, and system operations
- **Custom Workflows**: Build specialized agent teams for your specific needs

## Support and Resources

- **GitHub Repository**: https://github.com/docker/cagent
- **Documentation**: https://github.com/docker/cagent/blob/main/docs/USAGE.md
- **Contributing Guide**: https://github.com/docker/cagent/blob/main/docs/CONTRIBUTING.md
- **DigitalOcean Community**: https://www.digitalocean.com/community
- **Docker Community Slack**: https://dockercommunity.slack.com/archives/C09DASHHRU4

## Post-Deployment Notes

After deployment, you'll have:
- cagent binary installed at `/usr/local/bin/cagent`
- Docker pre-installed for running containerized models and tools
- Example agent configurations in `/opt/cagent/examples/`
- Quick reference guide at `/opt/cagent/README.txt`

### Next Steps

1. Set up your preferred AI provider API key
2. Try the example agents
3. Create your first custom agent with `cagent new`
4. Explore the MCP tool ecosystem
5. Build specialized agent teams for your workflows

### Important Notes

- **API Keys**: Store API keys securely in environment variables
- **Docker Model Runner**: Requires sufficient RAM for local model inference
- **Tool Installation**: Some MCP tools may require additional installation (npm, cargo)
- **Networking**: cagent primarily operates via CLI; no open ports required for basic usage
- **Updates**: Run `cagent --version` to check your version; update by downloading new releases

Perfect for developers, researchers, and teams looking to harness the power of AI agents for complex problem-solving and automation.
