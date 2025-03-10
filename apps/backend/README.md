# Smart Home System Backend

This is the backend service for the Smart Home System project. It provides APIs and services for managing smart home devices and automation.

## Installation

```bash
# Install dependencies
uv pip install .

# Install with development dependencies
uv pip install ".[dev]"

# Install in development mode
uv pip install -e .

# Install in development mode with development dependencies
uv pip install -e ".[dev]"
```

## Features

- Device management
- Automation rules
- API endpoints for frontend integration

## Development

This project uses uv for dependency management with dependencies defined in `pyproject.toml`.

To run the application:

```bash
python main.py
```

Or with uvicorn directly:

```bash
uvicorn main:app --reload
``` 