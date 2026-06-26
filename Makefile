MODE ?= cpu

.PHONY: help build upgrade start stop agent logs clean update-model

help:
	@echo "🚀 Pi Coding Agent + Llama.cpp Environment"
	@echo ""
	@echo "Usage: make [target] [MODE=cpu|gpu]"
	@echo "Default MODE is 'cpu'."
	@echo ""
	@echo "Available commands:"
	@echo "  make start      - Start the LLM environment in the background"
	@echo "  make agent      - Start and enter the interactive coding agent"
	@echo "  make stop       - Stop the environment"
	@echo "  make logs       - View logs for the running services"
	@echo "  make build      - Build the Docker images"
	@echo "  make upgrade    - Pull latest base images and rebuild without cache"
	@echo "  make clean      - Stop all and remove containers/networks/volumes"
	@echo "  make update-model - Update agent model config from .env (GPU_HF_MODEL)"
	@echo ""
	@echo "Examples:"
	@echo "  make start                (Starts in CPU mode)"
	@echo "  make start MODE=gpu       (Starts in GPU mode)"
	@echo "  make agent                (Enters agent using CPU mode config)"
	@echo "  make agent MODE=gpu       (Enters agent using GPU mode config)"
	@echo ""

build:
	docker compose -f docker-compose.$(MODE).yml build

upgrade:
	docker compose -f docker-compose.$(MODE).yml build --pull --no-cache

start:
	mkdir -p workspace models agent_data
	chmod 777 models agent_data
	docker compose -f docker-compose.$(MODE).yml up --build -d

stop:
	docker compose -f docker-compose.$(MODE).yml down

agent:
	docker compose -f docker-compose.$(MODE).yml run --rm agent

logs:
	docker compose -f docker-compose.$(MODE).yml logs -f

clean:
	docker compose -f docker-compose.cpu.yml down -v
	docker compose -f docker-compose.gpu.yml down -v

update-model:
	@MODEL=$$(sed -n 's/^GPU_HF_MODEL=//p' .env | tr -d '[:space:]'); \
	if [ -z "$$MODEL" ]; then \
		echo "Error: GPU_HF_MODEL not found in .env" >&2; \
		exit 1; \
	fi; \
	echo "Updating agent model to: $$MODEL"; \
	mkdir -p agent_data/agent; \
	printf '{\n  "defaultProvider": "llama-cpp",\n  "defaultModel": "%s"\n}\n' "$$MODEL" > agent_data/agent/settings.json; \
	printf '{\n  "providers": {\n    "llama-cpp": {\n      "baseUrl": "http://llm:8001/v1",\n      "api": "openai-completions",\n      "apiKey": "none",\n      "models": [\n        {\n          "id": "%s"\n        }\n      ]\n    }\n  }\n}\n' "$$MODEL" > agent_data/agent/models.json; \
	echo "Generated agent_data/agent/settings.json and agent_data/agent/models.json"
