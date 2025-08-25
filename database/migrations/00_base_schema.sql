-- Base schema for Archon V2 Alpha
-- Creates the fundamental tables required for the application

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- archon_settings table for application configuration and credentials
CREATE TABLE IF NOT EXISTS archon_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key TEXT NOT NULL UNIQUE,
    value TEXT,
    category TEXT DEFAULT 'general',
    description TEXT,
    is_encrypted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on category for faster lookups
CREATE INDEX IF NOT EXISTS idx_archon_settings_category ON archon_settings(category);

-- sources table for tracking crawled websites and uploaded documents
CREATE TABLE IF NOT EXISTS sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    url TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'website', -- 'website', 'upload', 'document'
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'crawling', 'completed', 'failed'
    title TEXT,
    description TEXT,
    metadata JSONB DEFAULT '{}',
    crawl_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- documents table for processed document chunks with embeddings
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES sources(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    title TEXT,
    content TEXT NOT NULL,
    content_length INTEGER,
    chunk_index INTEGER DEFAULT 0,
    embedding_768 vector(768),
    embedding_1024 vector(1024), 
    embedding_1536 vector(1536),
    embedding_3072 vector(3072),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indices for document searches
CREATE INDEX IF NOT EXISTS idx_documents_source_id ON documents(source_id);
CREATE INDEX IF NOT EXISTS idx_documents_url ON documents(url);

-- code_examples table for extracted code snippets
CREATE TABLE IF NOT EXISTS code_examples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES sources(id) ON DELETE CASCADE,
    language TEXT,
    framework TEXT,
    file_path TEXT,
    function_name TEXT,
    class_name TEXT,
    code_snippet TEXT NOT NULL,
    description TEXT,
    complexity_level TEXT,
    embedding_768 vector(768),
    embedding_1024 vector(1024),
    embedding_1536 vector(1536), 
    embedding_3072 vector(3072),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indices for code example searches
CREATE INDEX IF NOT EXISTS idx_code_examples_source_id ON code_examples(source_id);
CREATE INDEX IF NOT EXISTS idx_code_examples_language ON code_examples(language);

-- projects table (optional feature)
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'active', -- 'active', 'completed', 'archived'
    prd JSONB DEFAULT '{}', -- Product Requirements Document
    features JSONB DEFAULT '[]', -- Feature list
    docs JSONB DEFAULT '[]', -- Associated documents
    github_repo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- tasks table (optional feature) 
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    parent_task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'todo', -- 'todo', 'doing', 'review', 'done'
    assignee TEXT DEFAULT 'User',
    task_order INTEGER DEFAULT 0,
    feature TEXT,
    sources JSONB DEFAULT '[]',
    code_examples JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indices for task management
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_parent_task_id ON tasks(parent_task_id);

-- Insert default configuration values
INSERT INTO archon_settings (key, value, category, description) VALUES
    ('LLM_PROVIDER', 'openai', 'rag_strategy', 'Primary LLM provider'),
    ('EMBEDDING_PROVIDER', 'openai', 'rag_strategy', 'Primary embedding provider'),
    ('DEFAULT_EMBEDDING_MODEL', 'text-embedding-3-small', 'rag_strategy', 'Default embedding model'),
    ('DEFAULT_LLM_MODEL', 'gpt-4o-mini', 'rag_strategy', 'Default LLM model'),
    ('PROJECTS_ENABLED', 'false', 'features', 'Enable projects and tasks feature'),
    ('MAX_CRAWL_DEPTH', '3', 'crawling', 'Maximum crawl depth for websites'),
    ('MAX_CHUNK_SIZE', '1000', 'processing', 'Maximum chunk size for document processing')
ON CONFLICT (key) DO NOTHING;