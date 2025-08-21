-- ======================================================================
-- ADD MULTI-DIMENSIONAL VECTOR COLUMNS
-- ======================================================================
-- This migration adds support for multiple embedding dimensions
-- to handle different embedding models (768, 1024, 1536, 3072)
-- ======================================================================

BEGIN;

-- Add multi-dimensional columns to archon_crawled_pages
ALTER TABLE archon_crawled_pages 
ADD COLUMN IF NOT EXISTS embedding_768 VECTOR(768),
ADD COLUMN IF NOT EXISTS embedding_1024 VECTOR(1024),
ADD COLUMN IF NOT EXISTS embedding_1536 VECTOR(1536),
ADD COLUMN IF NOT EXISTS embedding_3072 VECTOR(3072),
ADD COLUMN IF NOT EXISTS embedding_model TEXT,
ADD COLUMN IF NOT EXISTS embedding_dimensions INTEGER;

-- Add multi-dimensional columns to archon_code_examples  
ALTER TABLE archon_code_examples
ADD COLUMN IF NOT EXISTS embedding_768 VECTOR(768),
ADD COLUMN IF NOT EXISTS embedding_1024 VECTOR(1024),
ADD COLUMN IF NOT EXISTS embedding_1536 VECTOR(1536),
ADD COLUMN IF NOT EXISTS embedding_3072 VECTOR(3072),
ADD COLUMN IF NOT EXISTS embedding_model TEXT,
ADD COLUMN IF NOT EXISTS embedding_dimensions INTEGER;

-- Create indexes for each dimension on archon_crawled_pages
CREATE INDEX IF NOT EXISTS idx_archon_crawled_pages_embedding_768 
ON archon_crawled_pages USING ivfflat (embedding_768 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_archon_crawled_pages_embedding_1024 
ON archon_crawled_pages USING ivfflat (embedding_1024 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_archon_crawled_pages_embedding_1536 
ON archon_crawled_pages USING ivfflat (embedding_1536 vector_cosine_ops) 
WITH (lists = 100);

-- Note: 3072 dimensions exceed HNSW's 2000 dimension limit
-- We skip the index for 3072 dimensions as sequential scan is acceptable
-- for this use case. Future optimization could include dimension reduction
-- or alternative indexing strategies.
-- CREATE INDEX IF NOT EXISTS idx_archon_crawled_pages_embedding_3072 
-- ON archon_crawled_pages USING hnsw (embedding_3072 vector_cosine_ops);

-- Create indexes for each dimension on archon_code_examples
CREATE INDEX IF NOT EXISTS idx_archon_code_examples_embedding_768 
ON archon_code_examples USING ivfflat (embedding_768 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_archon_code_examples_embedding_1024 
ON archon_code_examples USING ivfflat (embedding_1024 vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_archon_code_examples_embedding_1536 
ON archon_code_examples USING ivfflat (embedding_1536 vector_cosine_ops) 
WITH (lists = 100);

-- Note: 3072 dimensions exceed HNSW's 2000 dimension limit
-- We skip the index for 3072 dimensions as sequential scan is acceptable
-- for this use case. Future optimization could include dimension reduction
-- or alternative indexing strategies.
-- CREATE INDEX IF NOT EXISTS idx_archon_code_examples_embedding_3072 
-- ON archon_code_examples USING hnsw (embedding_3072 vector_cosine_ops);

-- Add function to detect embedding dimension from vector
CREATE OR REPLACE FUNCTION detect_embedding_dimension(embedding_vector vector)
RETURNS INTEGER AS $$
BEGIN
    RETURN array_length(embedding_vector::float[], 1);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Add function to get the appropriate column name for a dimension
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

-- Add comments for new embedding tracking columns
COMMENT ON COLUMN archon_crawled_pages.embedding_model IS 'The embedding model used to generate the embedding (e.g., text-embedding-3-small, all-mpnet-base-v2)';
COMMENT ON COLUMN archon_crawled_pages.embedding_dimensions IS 'The number of dimensions in the stored embedding vector';
COMMENT ON COLUMN archon_code_examples.embedding_model IS 'The embedding model used to generate the embedding (e.g., text-embedding-3-small, all-mpnet-base-v2)';
COMMENT ON COLUMN archon_code_examples.embedding_dimensions IS 'The number of dimensions in the stored embedding vector';

COMMIT;

-- Notify success
DO $$
BEGIN
    RAISE NOTICE '====================================================================';
    RAISE NOTICE '         MULTI-DIMENSIONAL VECTORS ADDED SUCCESSFULLY';
    RAISE NOTICE '====================================================================';
    RAISE NOTICE 'Added support for embedding dimensions: 768, 1024, 1536, 3072';
    RAISE NOTICE 'Created optimized indexes for each dimension';
    RAISE NOTICE '====================================================================';
END $$;