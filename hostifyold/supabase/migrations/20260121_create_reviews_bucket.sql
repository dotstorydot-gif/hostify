-- Create reviews bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'reviews',
  'reviews',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- RLS Policies for reviews bucket

-- 1. Public can view all review images
CREATE POLICY "Public can view review images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'reviews' );

-- 2. Authenticated users can upload review images
CREATE POLICY "Authenticated users can upload review images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'reviews' AND
  auth.role() = 'authenticated'
);

-- 3. Users can update their own review images
CREATE POLICY "Users can update own review images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'reviews' AND
  auth.uid() = owner
);

-- 4. Users can delete their own review images
CREATE POLICY "Users can delete own review images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'reviews' AND
  auth.uid() = owner
);
