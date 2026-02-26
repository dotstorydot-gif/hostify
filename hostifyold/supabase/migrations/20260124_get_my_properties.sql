-- Function to get properties for a landlord (owned or assigned)
CREATE OR REPLACE FUNCTION get_my_properties(p_user_id UUID)
RETURNS SETOF properties
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM properties p
  WHERE p.landlord_id = p_user_id
     OR EXISTS (
       SELECT 1 FROM property_landlords pl 
       WHERE pl.property_id = p.id AND pl.user_id = p_user_id
     )
  ORDER BY created_at DESC;
$$;
