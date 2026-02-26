      // BULK UPDATE Logic
      final propertUpdates = {
        '.Hostify Boutique Stays exclusive six-Ensuite villa': 500.0,
        '.Hostify Stays, Lagoons Paradise 3 ensuite Villa': 100.0,
        '.Hostify Stays, Amazing 5 master suite &private pool': 250.0,
        '.Hostify Stays, Ancient sands apartment': 90.0,
        '.Hostify Stays, Beautiful 3 master suite': 85.0,
        '.Hostify Stays, Cozy lagoons terrace one ensuite Apt': 100.0,
        '.Hostify Stays, Joubal Lagoons flowery apartment': 185.0,
        '.Hostify Stays, Luxurious Sea View, F.Marina Apt.': 120.0,
        '.Hostify Stays, Joubal Lagoons Terrace': 120.0,
      };

      void for (var entry in propertUpdates.entries) {
        final name = entry.key;
        final price = entry.value;
        
        // Find ID
        final response = await Supabase.instance.client.from('properties').select('id, ical_url').eq('name', name).maybeSingle();
        if (response != null) {
           final id = response['id'];
           final icalUrl = response['ical_url'];
           
           // Update Price
           await Supabase.instance.client.from('properties').update({'price_per_night': price}).eq('id', id);
           debugPrint('Updated $name to $price');
           
           // Sync
           if (icalUrl != null) {
              await ICalendarSyncService().syncCalendar(propertyId: id, icalUrl: icalUrl);
              debugPrint('Synced $name');
           }
        } else {
           debugPrint('Property NOT FOUND: $name');
           // Try partial match?
           // ...
        }
      }
