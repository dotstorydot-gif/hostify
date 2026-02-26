-- Create announcements/news table for admin to publish content
CREATE TABLE IF NOT EXISTS announcements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  image_url TEXT,
  target_audience TEXT NOT NULL CHECK (target_audience IN ('all', 'landlord', 'traveler', 'guest')),
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Index for fetching active announcements by audience
CREATE INDEX IF NOT EXISTS idx_announcements_active_audience 
ON announcements(is_active, target_audience, created_at DESC);

-- RLS Policies
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read active announcements
-- (App logic will filter by target_audience on the client side)
CREATE POLICY "Users can view active announcements"
ON announcements
FOR SELECT
TO authenticated
USING (is_active = true);

-- Only authenticated users can insert announcements
-- (In production, you would check admin status via user_roles table or a custom function)
CREATE POLICY "Authenticated users can create announcements"
ON announcements
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Users can update their own announcements
CREATE POLICY "Users can update own announcements"
ON announcements
FOR UPDATE
TO authenticated
USING (created_by = auth.uid());

-- Users can delete their own announcements  
CREATE POLICY "Users can delete own announcements"
ON announcements
FOR DELETE
TO authenticated
USING (created_by = auth.uid());

-- Create storage bucket for announcement images
INSERT INTO storage.buckets (id, name, public)
VALUES ('announcements', 'announcements', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for announcement images
CREATE POLICY "Authenticated users can upload announcement images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'announcements');

CREATE POLICY "Anyone can view announcement images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'announcements');

CREATE POLICY "Users can delete their announcement images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'announcements');
