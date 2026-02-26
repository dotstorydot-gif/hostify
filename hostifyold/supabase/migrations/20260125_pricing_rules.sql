-- Create table for property pricing rules (Holiday Pricing)
CREATE TABLE IF NOT EXISTS public.property_pricing_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  percentage_increase INTEGER NOT NULL DEFAULT 0, -- e.g. 20 for 20% increase
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate rules for same property/date
  UNIQUE(property_id, date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pricing_rules_property_date ON public.property_pricing_rules(property_id, date);

-- RLS
ALTER TABLE public.property_pricing_rules ENABLE ROW LEVEL SECURITY;

-- Policies
-- Admins and Landlords can view/edit their own property rules
CREATE POLICY "Admins and Landlords can view pricing rules"
ON public.property_pricing_rules FOR SELECT
USING (
  auth.uid() IN (SELECT user_id FROM property_landlords WHERE property_id = property_pricing_rules.property_id)
  OR
  auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  OR
  EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid())
);

CREATE POLICY "Admins and Landlords can insert pricing rules"
ON public.property_pricing_rules FOR INSERT
WITH CHECK (
  auth.uid() IN (SELECT user_id FROM property_landlords WHERE property_id = property_pricing_rules.property_id)
  OR
  auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  OR
  EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid())
);

CREATE POLICY "Admins and Landlords can update pricing rules"
ON public.property_pricing_rules FOR UPDATE
USING (
  auth.uid() IN (SELECT user_id FROM property_landlords WHERE property_id = property_pricing_rules.property_id)
  OR
  auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  OR
  EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid())
);

CREATE POLICY "Admins and Landlords can delete pricing rules"
ON public.property_pricing_rules FOR DELETE
USING (
  auth.uid() IN (SELECT user_id FROM property_landlords WHERE property_id = property_pricing_rules.property_id)
  OR
  auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  OR
  EXISTS (SELECT 1 FROM properties WHERE id = property_id AND landlord_id = auth.uid())
);

-- Public/Travelers need to read rules to calculate price? 
-- Actually, calculation happens on server (RPC) or provider fetch.
-- If client calculates, they need SELECT permission.
-- Let's allow public read for now to facilitate price calculation
CREATE POLICY "Public can view pricing rules"
ON public.property_pricing_rules FOR SELECT
USING (true);

COMMENT ON TABLE public.property_pricing_rules IS 'Stores daily price modifiers (percentage increase) for properties.';
