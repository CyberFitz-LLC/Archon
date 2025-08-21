# Ollama Integration Guide

This guide explains how to configure and use Ollama with Archon V2 Alpha.

## Overview

Ollama support has been added to Archon, allowing you to use local LLM models for both chat and embedding operations. This integration requires explicit configuration with no hardcoded defaults.

## Configuration Requirements

### Required Settings

When using Ollama as your LLM provider, you MUST configure the following settings in the UI (Settings > RAG Settings):

1. **LLM Provider**: Select "Ollama" from the dropdown
2. **Ollama LLM Base URL**: The URL for your Ollama instance's LLM API (e.g., `http://localhost:11434/v1`)
3. **Ollama Embedding Base URL**: The URL for your Ollama instance's embedding API (e.g., `http://localhost:11434/v1`)
4. **Embedding Model**: The embedding model to use (e.g., `nomic-embed-text`, `mxbai-embed-large`)

### Why Two URLs?

Archon supports using different Ollama instances or configurations for LLM and embedding operations:
- **LLM Base URL**: Used for chat completions and text generation
- **Embedding Base URL**: Used for creating embeddings for RAG search

This allows you to:
- Use different Ollama instances for each service
- Configure load balancing separately for each service type
- Use specialized hardware for embeddings vs chat

## Supported Embedding Models

The system supports multiple embedding dimensions:
- **768 dimensions**: Models like `nomic-embed-text` (768d variant)
- **1024 dimensions**: Custom models requiring 1024d
- **1536 dimensions**: OpenAI-compatible models, `text-embedding-3-small`
- **3072 dimensions**: Large models like `text-embedding-3-large`

## Database Migration

If you're upgrading an existing installation, run the multi-dimensional vector migration:

```sql
-- Run this in your Supabase SQL editor
-- Location: migration/add_multi_dimensional_vectors.sql
```

This adds support for different embedding dimensions to handle various models.

## Example Configuration

### Basic Setup (Single Ollama Instance)

```
LLM Provider: Ollama
Ollama LLM Base URL: http://localhost:11434/v1
Ollama Embedding Base URL: http://localhost:11434/v1
Embedding Model: nomic-embed-text
```

### Advanced Setup (Separate Instances)

```
LLM Provider: Ollama
Ollama LLM Base URL: http://llm-server:11434/v1
Ollama Embedding Base URL: http://embedding-server:11434/v1
Embedding Model: mxbai-embed-large
```

## Troubleshooting

### Error: "Ollama requires LLM_BASE_URL to be configured"
- Go to Settings > RAG Settings
- Enter your Ollama instance URL in the "Ollama LLM Base URL" field
- Save the settings

### Error: "Ollama requires EMBEDDING_MODEL to be configured"
- Go to Settings > RAG Settings
- Enter your embedding model name in the "Embedding Model" field
- Common models: `nomic-embed-text`, `mxbai-embed-large`, `all-minilm`
- Save the settings

### Error: "Ollama requires EMBEDDING_BASE_URL to be configured"
- Go to Settings > RAG Settings
- Enter your Ollama instance URL in the "Ollama Embedding Base URL" field
- This can be the same as the LLM Base URL if using a single instance
- Save the settings

## Security Considerations

- Never hardcode Ollama URLs in the code
- Always configure URLs through the Settings UI
- Use HTTPS when connecting to remote Ollama instances
- Configure proper authentication if exposing Ollama over the network

## Performance Tips

1. **Model Selection**: Choose embedding models based on your needs:
   - Smaller models (768d) for faster processing
   - Larger models (1536d, 3072d) for better accuracy

2. **Resource Allocation**: 
   - Dedicate sufficient RAM for your chosen models
   - Consider GPU acceleration for large models

3. **Load Balancing** (Future Feature):
   - Will support multiple Ollama instances for high availability
   - Separate configuration for LLM and embedding load balancing

## API Compatibility

Ollama integration uses the OpenAI-compatible API, ensuring:
- Seamless switching between providers
- Consistent API interface
- No code changes needed when switching providers

## Next Steps

After configuration:
1. Test the connection using the chat interface
2. Crawl or upload documents to test embeddings
3. Verify RAG search functionality
4. Monitor performance and adjust settings as needed