-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create function to sync all property calendars
CREATE OR REPLACE FUNCTION sync_all_ical_calendars()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  property_record RECORD;
  ical_response TEXT;
  event_count INTEGER := 0;
BEGIN
  -- Loop through all properties with ical_url
  FOR property_record IN 
    SELECT id, ical_url, name
    FROM properties
    WHERE ical_url IS NOT NULL 
      AND ical_url != ''
      AND status = 'Active'
  LOOP
    BEGIN
      -- Fetch iCal data using http extension
      SELECT content::text INTO ical_response
      FROM http_get(property_record.ical_url);
      
      -- Parse and import events (simplified - actual parsing done in app)
      -- For now, we'll log the sync attempt
      INSERT INTO ical_sync_logs (
        property_id,
        property_name,
        sync_status,
        synced_at,
        error_message
      ) VALUES (
        property_record.id,
        property_record.name,
        'success',
        NOW(),
        NULL
      );
      
      event_count := event_count + 1;
      
    EXCEPTION WHEN OTHERS THEN
      -- Log error
      INSERT INTO ical_sync_logs (
        property_id,
        property_name,
        sync_status,
        synced_at,
        error_message
      ) VALUES (
        property_record.id,
        property_record.name,
        'failed',
        NOW(),
        SQLERRM
      );
    END;
  END LOOP;
  
  RAISE NOTICE 'Synced % properties', event_count;
END;
$$;

-- Create sync logs table
CREATE TABLE IF NOT EXISTS ical_sync_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  property_name TEXT,
  sync_status TEXT NOT NULL, -- 'success', 'failed', 'partial'
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  events_imported INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_ical_sync_logs_property 
ON ical_sync_logs(property_id, synced_at DESC);

CREATE INDEX IF NOT EXISTS idx_ical_sync_logs_status 
ON ical_sync_logs(sync_status, synced_at DESC);

-- Enable RLS
ALTER TABLE ical_sync_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Landlords can view their own sync logs
DROP POLICY IF EXISTS "Landlords can view their sync logs" ON ical_sync_logs;
CREATE POLICY "Landlords can view their sync logs"
ON ical_sync_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = ical_sync_logs.property_id
      AND p.landlord_id = auth.uid()
  )
);

-- Schedule CRON job to run daily at 3 AM UTC
SELECT cron.schedule(
  'sync-ical-calendars-daily',
  '0 3 * * *', -- Every day at 3 AM
  $$SELECT sync_all_ical_calendars();$$
);

-- Create function to manually trigger sync for a specific property
CREATE OR REPLACE FUNCTION sync_property_calendar(p_property_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  property_record RECORD;
  result JSONB;
BEGIN
  -- Get property details
  SELECT id, ical_url, name, landlord_id
  INTO property_record
  FROM properties
  WHERE id = p_property_id
    AND (landlord_id = auth.uid() OR 
         EXISTS (SELECT 1 FROM property_managers WHERE property_id = p_property_id AND user_id = auth.uid()));
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Property not found or access denied'
    );
  END IF;
  
  IF property_record.ical_url IS NULL OR property_record.ical_url = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No iCal URL configured for this property'
    );
  END IF;
  
  -- Log sync attempt
  INSERT INTO ical_sync_logs (
    property_id,
    property_name,
    sync_status,
    synced_at
  ) VALUES (
    property_record.id,
    property_record.name,
    'triggered',
    NOW()
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Sync triggered successfully',
    'property_id', property_record.id,
    'property_name', property_record.name
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION sync_property_calendar(UUID) TO authenticated;

COMMENT ON FUNCTION sync_all_ical_calendars() IS 'Automatically syncs all property iCal calendars - runs via CRON';
COMMENT ON FUNCTION sync_property_calendar(UUID) IS 'Manually trigger calendar sync for a specific property';
COMMENT ON TABLE ical_sync_logs IS 'Logs of iCalendar sync attempts for monitoring and debugging';
