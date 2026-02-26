-- Fix for "Function Search Path Mutable" lint issue
-- Function: public.get_my_properties
-- Security improvement: Set explicit search_path and use schema-qualified names

CREATE OR REPLACE FUNCTION public.get_my_properties(p_user_id UUID)
RETURNS SETOF public.properties
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.properties p
  WHERE p.landlord_id = p_user_id
     OR EXISTS (
       SELECT 1 FROM public.property_landlords pl 
       WHERE pl.property_id = p.id AND pl.user_id = p_user_id
     )
  ORDER BY created_at DESC;
$$;
