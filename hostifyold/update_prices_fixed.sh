#!/bin/bash
API_URL="https://zxauivjmynopybpncxlk.supabase.co/rest/v1/properties"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4YXVpdmpteW5vcHlicG5jeGxrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3MzY1NTYsImV4cCI6MjA4NDMxMjU1Nn0.ix4UAcXo81lU0o4mlFvkPWtIkEEJLY8j016RPln98uM"

# 1. Cozy lagoons ($100)
curl -X PATCH "$API_URL?id=eq.4f8bd8a0-1873-4b48-97a0-c6eb72b9a05f" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 100}'

# 2. Amazing 5 ($250)
curl -X PATCH "$API_URL?id=eq.5b4dd8bd-25d4-47f2-837e-5f26b20de65c" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 250}'

# 3. Lagoons Paradise 3 ($100)
curl -X PATCH "$API_URL?id=eq.4b9fc392-0fe5-442a-800c-d38851cd93ed" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 100}'

# 4. Ancient sands ($90)
curl -X PATCH "$API_URL?id=eq.0ee2e807-bd0d-44ce-9991-57cb8868181f" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 90}'

# 5. Luxurious Sea View ($120)
curl -X PATCH "$API_URL?id=eq.aa325035-b12a-4789-b996-610511a04738" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 120}'

# 6. Joubal Lagoons Terrace ($120)
curl -X PATCH "$API_URL?id=eq.50756e24-a562-444c-befc-ec7064df54ea" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 120}'

# 7. Joubal Lagoons Flowery ($185)
curl -X PATCH "$API_URL?id=eq.1a0aaf9b-9914-4e4b-b340-477c4a9d9f5f" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 185}'

# 8. Beautiful 3 master ($85)
curl -X PATCH "$API_URL?id=eq.fd09171e-0687-4bf4-b942-f7d547267013" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 85}'

# 9. Six-Ensuite ($500)
curl -X PATCH "$API_URL?id=eq.58f5d9aa-c267-43b8-836b-42feb57923bb" \
-H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" -H "Content-Type: application/json" \
-d '{"price_per_night": 500}'
