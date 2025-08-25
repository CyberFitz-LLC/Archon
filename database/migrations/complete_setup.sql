-- ======================================================================
-- ARCHON V2 ALPHA - COMPLETE DATABASE SETUP
-- ======================================================================
-- Complete schema setup including base tables and multi-dimensional vectors
-- This file creates all required tables, indexes, functions, and default data
-- ======================================================================

BEGIN;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ======================================================================
-- CORE TABLES
-- ======================================================================

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

-- documents table for processed document chunks with multi-dimensional embeddings
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

-- code_examples table for extracted code snippets with multi-dimensional embeddings
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

-- ======================================================================
-- MULTI-DIMENSIONAL VECTOR INDEXES
-- ======================================================================

-- Create optimized indexes for each embedding dimension on documents table
-- IVFFlat indexes for smaller dimensions (768, 1024, 1536)
CREATE INDEX IF NOT EXISTS idx_documents_embedding_768 
ON documents USING ivfflat (embedding_768 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_documents_embedding_1024 
ON documents USING ivfflat (embedding_1024 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_documents_embedding_1536 
ON documents USING ivfflat (embedding_1536 vector_cosine_ops) 
WITH (lists = 100);

-- Note: 3072 dimensions exceed pgvector's 2000 dimension index limit
-- Searches on 3072-dimensional embeddings will use sequential scans
-- Consider using dimension reduction or chunking for high-dimensional embeddings

-- Create optimized indexes for each embedding dimension on code_examples table
CREATE INDEX IF NOT EXISTS idx_code_examples_embedding_768 
ON code_examples USING ivfflat (embedding_768 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_code_examples_embedding_1024 
ON code_examples USING ivfflat (embedding_1024 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_code_examples_embedding_1536 
ON code_examples USING ivfflat (embedding_1536 vector_cosine_ops) 
WITH (lists = 100);

-- Note: 3072 dimensions exceed pgvector's 2000 dimension index limit
-- Sequential scans will be used for 3072-dimensional embedding searches

-- ======================================================================
-- UTILITY FUNCTIONS FOR MULTI-DIMENSIONAL VECTORS
-- ======================================================================

-- Function to detect embedding dimension from vector
CREATE OR REPLACE FUNCTION detect_embedding_dimension(embedding_vector vector)
RETURNS INTEGER AS $$
BEGIN
    RETURN array_length(embedding_vector::float[], 1);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get the appropriate column name for a dimension
CREATE OR REPLACE FUNCTION get_embedding_column_name(dimension INTEGER)
RETURNS TEXT AS $$
BEGIN
    CASE dimension
        WHEN 768 THEN RETURN 'embedding_768';
        WHEN 1024 THEN RETURN 'embedding_1024';
        WHEN 1536 THEN RETURN 'embedding_1536';
        WHEN 3072 THEN RETURN 'embedding_3072';
        ELSE RAISE EXCEPTION 'Unsupported embedding dimension: %', dimension;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to perform similarity search with automatic dimension detection
CREATE OR REPLACE FUNCTION search_similar_documents(
    query_embedding vector,
    similarity_threshold float DEFAULT 0.7,
    max_results integer DEFAULT 10
)
RETURNS TABLE (
    document_id UUID,
    title TEXT,
    content TEXT,
    url TEXT,
    similarity_score FLOAT
) AS $$
DECLARE
    dimension_size INTEGER;
    query_sql TEXT;
BEGIN
    -- Detect the dimension of the query embedding
    dimension_size := detect_embedding_dimension(query_embedding);
    
    -- Build dynamic query based on dimension
    query_sql := format('
        SELECT 
            id as document_id,
            title,
            content,
            url,
            1 - (embedding_%s <=> $1) as similarity_score
        FROM documents 
        WHERE embedding_%s IS NOT NULL
        AND (1 - (embedding_%s <=> $1)) >= $2
        ORDER BY embedding_%s <=> $1
        LIMIT $3',
        dimension_size, dimension_size, dimension_size, dimension_size
    );
    
    -- Execute the dynamic query
    RETURN QUERY EXECUTE query_sql USING query_embedding, similarity_threshold, max_results;
END;
$$ LANGUAGE plpgsql;

-- Function to perform similarity search on code examples
CREATE OR REPLACE FUNCTION search_similar_code_examples(
    query_embedding vector,
    similarity_threshold float DEFAULT 0.7,
    max_results integer DEFAULT 10
)
RETURNS TABLE (
    code_id UUID,
    language TEXT,
    framework TEXT,
    function_name TEXT,
    code_snippet TEXT,
    description TEXT,
    similarity_score FLOAT
) AS $$
DECLARE
    dimension_size INTEGER;
    query_sql TEXT;
BEGIN
    -- Detect the dimension of the query embedding
    dimension_size := detect_embedding_dimension(query_embedding);
    
    -- Build dynamic query based on dimension
    query_sql := format('
        SELECT 
            id as code_id,
            language,
            framework,
            function_name,
            code_snippet,
            description,
            1 - (embedding_%s <=> $1) as similarity_score
        FROM code_examples 
        WHERE embedding_%s IS NOT NULL
        AND (1 - (embedding_%s <=> $1)) >= $2
        ORDER BY embedding_%s <=> $1
        LIMIT $3',
        dimension_size, dimension_size, dimension_size, dimension_size
    );
    
    -- Execute the dynamic query
    RETURN QUERY EXECUTE query_sql USING query_embedding, similarity_threshold, max_results;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- DEFAULT CONFIGURATION VALUES
-- ======================================================================

-- Insert default configuration values
INSERT INTO archon_settings (key, value, category, description) VALUES
    ('LLM_PROVIDER', 'openai', 'rag_strategy', 'Primary LLM provider'),
    ('EMBEDDING_PROVIDER', 'openai', 'rag_strategy', 'Primary embedding provider'),
    ('DEFAULT_EMBEDDING_MODEL', 'text-embedding-3-small', 'rag_strategy', 'Default embedding model'),
    ('DEFAULT_LLM_MODEL', 'gpt-4o-mini', 'rag_strategy', 'Default LLM model'),
    ('PROJECTS_ENABLED', 'false', 'features', 'Enable projects and tasks feature'),
    ('MAX_CRAWL_DEPTH', '3', 'crawling', 'Maximum crawl depth for websites'),
    ('MAX_CHUNK_SIZE', '1000', 'processing', 'Maximum chunk size for document processing'),
    ('SUPPORTED_EMBEDDING_DIMENSIONS', '768,1024,1536,3072', 'embeddings', 'Supported embedding dimensions'),
    ('DEFAULT_EMBEDDING_DIMENSION', '1536', 'embeddings', 'Default embedding dimension for new content')
ON CONFLICT (key) DO NOTHING;

COMMIT;

-- ======================================================================
-- SUCCESS NOTIFICATION
-- ======================================================================

DO $$
BEGIN
    RAISE NOTICE '====================================================================';
    RAISE NOTICE '           ARCHON V2 ALPHA DATABASE SETUP COMPLETE';
    RAISE NOTICE '====================================================================';
    RAISE NOTICE 'Created tables: archon_settings, sources, documents, code_examples, projects, tasks';
    RAISE NOTICE 'Added multi-dimensional vector support: 768, 1024, 1536, 3072 dimensions';
    RAISE NOTICE 'Created optimized indexes: IVFFlat for dimensions ≤1536 (768, 1024, 1536)';
    RAISE NOTICE 'Added utility functions: detect_embedding_dimension, get_embedding_column_name';
    RAISE NOTICE 'Added search functions: search_similar_documents, search_similar_code_examples';
    RAISE NOTICE 'Inserted default configuration values';
    RAISE NOTICE '====================================================================';
END $$;