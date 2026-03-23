Welcome to Docker Agent on DigitalOcean!

Docker Agent (from docker/docker-agent) is an AI Agent Builder and Runtime that lets you
create and run intelligent AI agents with specialized capabilities and tools.
Use the docker-agent CLI to run and manage agents.

GETTING STARTED
===============

1. Set your API keys for AI providers (choose based on your needs):

   # For OpenAI models
   export OPENAI_API_KEY=your_api_key_here

   # For Anthropic models
   export ANTHROPIC_API_KEY=your_api_key_here

   # For Google Gemini models
   export GOOGLE_API_KEY=your_api_key_here

   # DigitalOcean Inference (Gradient) - create at https://cloud.digitalocean.com/gen-ai
   export DO_GRADIENT_API_KEY=your_gradient_key_here

2. Run example agents:

   # Run a basic agent (requires OPENAI_API_KEY)
   docker-agent run /opt/docker-agent/examples/basic_agent.yaml

   # Run a local agent using Docker Model Runner (no API key needed)
   docker-agent run /opt/docker-agent/examples/dmr.yaml

   # Run other examples
   docker-agent run /opt/docker-agent/examples/pirate.yaml          # Fun pirate assistant
   docker-agent run /opt/docker-agent/examples/pythonist.yaml       # Python expert
   docker-agent run /opt/docker-agent/examples/todo.yaml            # Task manager

3. Create your own agents:

   # Generate a new agent configuration interactively
   docker-agent new

   # Create agents from prompts
   docker-agent new --model openai/gpt-4o-mini

4. Pull and run agents from Docker Hub:

   docker-agent run creek/pirate

USEFUL COMMANDS
===============

# View available commands
docker-agent --help

# Pull an agent from Docker Hub
docker-agent pull docker.io/username/my-agent:latest

# Push your agent to Docker Hub
docker-agent push ./my-agent.yaml docker.io/username/my-agent:latest

# Build a Docker image for your agent
docker-agent build ./my-agent.yaml my-agent:latest

DOCUMENTATION
=============

Project:     https://github.com/docker/docker-agent
Usage guide: https://github.com/docker/docker-agent/blob/main/docs/USAGE.md
Examples:    https://github.com/docker/docker-agent/tree/main/examples

NOTES
=====

- Docker Model Runner (DMR) allows running local AI models without API keys
- Enable DMR in Docker Desktop settings or via CLI for Docker Engine
- Example configurations are in /opt/docker-agent/examples/
- Agent configurations are YAML files describing models, tools, and behavior

DigitalOcean Inference (Gradient)
=================================
Create a model access key at https://cloud.digitalocean.com/gen-ai then:
  export DO_GRADIENT_API_KEY=your_key

Use in your agent YAML (define model in models section with base_url/token_key):
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

For questions and support, visit: https://github.com/docker/docker-agent
