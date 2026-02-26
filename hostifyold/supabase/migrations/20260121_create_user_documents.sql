-- Create user_documents table
CREATE TABLE IF NOT EXISTS user_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_documents ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_documents
DROP POLICY IF EXISTS "Users can view their own documents" ON user_documents;
CREATE POLICY "Users can view their own documents" 
  ON user_documents FOR SELECT 
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own documents" ON user_documents;
CREATE POLICY "Users can insert their own documents" 
  ON user_documents FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own documents" ON user_documents;
CREATE POLICY "Users can delete their own documents" 
  ON user_documents FOR DELETE 
  USING (auth.uid() = user_id);

-- Create storage bucket for documents if not exists
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies
-- We use a DO block here to safely handle policy drops and creations on the storage schema
DO $$
BEGIN
  -- Upload Policy
  DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
  CREATE POLICY "Users can upload their own documents" 
    ON storage.objects FOR INSERT 
    WITH CHECK ( bucket_id = 'documents' AND auth.uid() = owner );

  -- Select Policy
  DROP POLICY IF EXISTS "Users can view their own documents" ON storage.objects;
  CREATE POLICY "Users can view their own documents" 
    ON storage.objects FOR SELECT 
    USING ( bucket_id = 'documents' AND auth.uid() = owner );
  
  -- Delete Policy
  DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
  CREATE POLICY "Users can delete their own documents" 
    ON storage.objects FOR DELETE 
    USING ( bucket_id = 'documents' AND auth.uid() = owner );
END $$;
