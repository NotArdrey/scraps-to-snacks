import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

console.log("Hello from scan-pantry!")

Deno.serve(async (req) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
    }

    try {
        // Extract and validate authorization
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            throw new Error('No authorization header');
        }

        // Create Supabase client with the user's JWT to get authenticated user
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            {
                global: {
                    headers: { Authorization: authHeader },
                },
            }
        );

        // Get the authenticated user
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
        if (authError || !user) {
            throw new Error('Unauthorized');
        }

        const { imageUrl } = await req.json()

        if (!imageUrl) throw new Error('No imageUrl provided')

        const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY')
        if (!GROQ_API_KEY) throw new Error('Missing GROQ_API_KEY')

        // Download image to base64 for Groq Vision (chunked to avoid stack overflow)
        const imageResp = await fetch(imageUrl);
        const imageBlob = await imageResp.blob();
        const arrayBuffer = await imageBlob.arrayBuffer();
        const uint8Array = new Uint8Array(arrayBuffer);
        
        // Convert to base64 in chunks to avoid stack overflow
        let binary = '';
        const chunkSize = 8192;
        for (let i = 0; i < uint8Array.length; i += chunkSize) {
            const chunk = uint8Array.subarray(i, i + chunkSize);
            binary += String.fromCharCode.apply(null, chunk as unknown as number[]);
        }
        const base64Image = btoa(binary);

        // Call Groq API with Llama Vision model
        const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${GROQ_API_KEY}`,
            },
            body: JSON.stringify({
                model: 'meta-llama/llama-4-scout-17b-16e-instruct',
                messages: [{
                    role: 'user',
                    content: [
                        {
                            type: 'text',
                            text: `Identify the food items in this image. 
                     For each item, estimate a safe shelf life in days from today (conservative estimate). 
                     Return strictly valid JSON array (no markdown) with this schema:
                     [ { "name": "Milk", "days_to_expire": 7 }, ... ]`
                        },
                        {
                            type: 'image_url',
                            image_url: {
                                url: `data:${imageBlob.type};base64,${base64Image}`
                            }
                        }
                    ]
                }],
                temperature: 0.7,
            }),
        })

        const data = await response.json()

        if (data.error) {
            console.error('Groq Error:', JSON.stringify(data.error));
            throw new Error(`Groq API Error: ${data.error.message || JSON.stringify(data.error)}`);
        }

        // Extract JSON
        let text = data.choices?.[0]?.message?.content;
        if (!text) throw new Error('No content from Groq');

        text = text.replace(/```json/g, '').replace(/```/g, '').trim();
        const items = JSON.parse(text);

        // Prepare DB Inserts
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const inserts = items.map((item: any) => {
            const expiryDate = new Date();
            expiryDate.setDate(expiryDate.getDate() + (item.days_to_expire || 7)); // Default 7 if missing

            return {
                user_id: user.id,
                name: item.name,
                expiry_date: expiryDate.toISOString()
            }
        });

        const { error } = await supabase.from('ingredients').insert(inserts);

        if (error) throw error;

        return new Response(
            JSON.stringify({ success: true, items: inserts }),
            { headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' } },
        )
    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' } },
        )
    }
})
