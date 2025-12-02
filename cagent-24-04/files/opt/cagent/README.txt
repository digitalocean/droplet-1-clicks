Welcome to cagent on DigitalOcean!

cagent is a powerful multi-agent AI runtime that orchestrates AI agents with 
specialized capabilities and tools.

GETTING STARTED
===============

1. Set your API keys for AI providers (choose based on your needs):
   
   # For OpenAI models
   export OPENAI_API_KEY=your_api_key_here
   
   # For Anthropic models
   export ANTHROPIC_API_KEY=your_api_key_here
   
   # For Google Gemini models
   export GOOGLE_API_KEY=your_api_key_here

2. Run example agents:
   
   # Run a basic agent (requires OPENAI_API_KEY)
   cagent run /opt/cagent/examples/basic_agent.yaml
   
   # Run a local agent using Docker Model Runner (no API key needed)
   cagent run /opt/cagent/examples/dmr.yaml
   
   # Run other examples
   cagent run /opt/cagent/examples/pirate.yaml          # Fun pirate assistant
   cagent run /opt/cagent/examples/pythonist.yaml       # Python expert
   cagent run /opt/cagent/examples/todo.yaml            # Task manager

3. Create your own agents:
   
   # Generate a new agent configuration interactively
   cagent new
   
   # Create agents from prompts
   cagent new --model openai/gpt-4o-mini

4. Pull and run agents from Docker Hub:
   
   cagent run creek/pirate

USEFUL COMMANDS
===============

# View available commands
cagent --help

# Pull an agent from Docker Hub
cagent pull docker.io/username/my-agent:latest

# Push your agent to Docker Hub
cagent push ./my-agent.yaml docker.io/username/my-agent:latest

# Build a Docker image for your agent
cagent build ./my-agent.yaml my-agent:latest

DOCUMENTATION
=============

Full documentation: https://github.com/docker/cagent
Usage guide: https://github.com/docker/cagent/blob/main/docs/USAGE.md
Examples: https://github.com/docker/cagent/tree/main/examples

NOTES
=====

- Docker Model Runner (DMR) allows running local AI models without API keys
- Enable DMR in Docker Desktop settings or via CLI for Docker Engine
- Example configurations are in /opt/cagent/examples/
- Agent configurations are YAML files describing models, tools, and behavior

For questions and support, visit: https://github.com/docker/cagent
