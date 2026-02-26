import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import ICAL from "https://esm.sh/ical.js@1.5.0"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Create Supabase Client (Admin Context)
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        console.log("Starting Sync...")

        // 1. Fetch properties with iCal URLs
        const { data: properties, error: propError } = await supabaseClient
            .from('properties')
            .select('id, name, ical_url')

        if (propError) throw propError

        let totalSynced = 0;

        for (const prop of properties) {
            if (prop.ical_url) {
                console.log(`Syncing ${prop.name}...`)

                try {
                    // 2. Fetch ICS content
                    const icsResponse = await fetch(prop.ical_url)
                    if (!icsResponse.ok) {
                        console.error(`Failed to fetch ICS for ${prop.name}: ${icsResponse.status}`)
                        continue
                    }

                    const icsData = await icsResponse.text()

                    // 3. Parse ICS
                    const jcalData = ICAL.parse(icsData)
                    const comp = new ICAL.Component(jcalData)
                    const vevents = comp.getAllSubcomponents('vevent')

                    const bookingsToUpsert = []

                    for (const event of vevents) {
                        const eventObj = new ICAL.Event(event)
                        const uid = eventObj.uid
                        const summary = eventObj.summary || 'External Guest'
                        const startDate = eventObj.startDate.toJSDate()
                        const endDate = eventObj.endDate.toJSDate()

                        // Calculate nights
                        const diffTime = Math.abs(endDate.getTime() - startDate.getTime());
                        const nights = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

                        let source = 'hostify'
                        if (summary.toLowerCase().includes('airbnb')) source = 'airbnb'
                        else if (summary.toLowerCase().includes('booking.com')) source = 'booking_com'

                        // Prepare Upsert Record
                        // Note: total_price is 0, let SQL handle logic
                        // Using a specific guest_id or making it NULL (which allows us to skip it as we updated schema)

                        bookingsToUpsert.push({
                            property_id: prop.id,
                            check_in: startDate.toISOString(),
                            check_out: endDate.toISOString(),
                            nights: nights,
                            total_price: 0,
                            status: 'confirmed',
                            booking_source: source,
                            external_booking_id: uid,
                            unit_name: 'Imported',
                            // guest_id is omitted (NULL)
                        })
                    }

                    // 4. Batch Upsert
                    if (bookingsToUpsert.length > 0) {
                        // We need to check existence if we want to avoid duplicates or use UPSERT on unique constraint.
                        // bookings table might not have unique constraint on external_booking_id yet. 
                        // We should check first or add unique constraint. 
                        // For safety, checking individual (slow) or assume upsert if constraint exists.
                        // Given limitations, let's fetch existing for this prop and filter.

                        // Simplest: Loop and insert if not exists (inefficient but safe)
                        for (const b of bookingsToUpsert) {
                            const { data: existing } = await supabaseClient
                                .from('bookings')
                                .select('id')
                                .eq('external_booking_id', b.external_booking_id)
                                .maybeSingle()

                            if (!existing) {
                                await supabaseClient.from('bookings').insert(b)
                                totalSynced++;
                            }
                        }
                    }

                } catch (e: any) {
                    console.error(`Error processing ${prop.name}: ${e.message}`)
                }
            }
        }

        return new Response(
            JSON.stringify({ message: 'Sync complete', synced: totalSynced }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
