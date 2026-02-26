-- Create property_images table for storing multiple images per property
CREATE TABLE IF NOT EXISTS public.property_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_property_images_property_id ON public.property_images(property_id);
CREATE INDEX IF NOT EXISTS idx_property_images_is_primary ON public.property_images(is_primary);

-- Enable RLS
ALTER TABLE public.property_images ENABLE ROW LEVEL SECURITY;

-- Allow everyone to read property images
CREATE POLICY "Property images are viewable by everyone" 
ON public.property_images FOR SELECT 
USING (true);

-- Allow authenticated users to insert/update/delete their own property images
CREATE POLICY "Users can manage their property images" 
ON public.property_images FOR ALL 
USING (
  auth.uid() IN (
    SELECT landlord_id FROM properties WHERE id = property_id
  )
);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_property_images_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_property_images_timestamp
BEFORE UPDATE ON public.property_images
FOR EACH ROW
EXECUTE FUNCTION update_property_images_updated_at();

COMMENT ON TABLE public.property_images IS 'Stores multiple images for each property with primary image designation';
