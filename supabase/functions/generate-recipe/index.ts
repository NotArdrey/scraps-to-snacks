import "jsr:@supabase/functions-js/edge-runtime.d.ts"

console.log("Hello from Functions!")

Deno.serve(async (req) => {
    // 1. Handle Preflight (The "Can I talk to you?" check)
    if (req.method === 'OPTIONS') {
        return new Response('ok', {
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
            }
        })
    }

    try {
        // Extract authorization header to verify user is authenticated
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            throw new Error('No authorization header');
        }

        const { ingredients } = await req.json()

        // 2. Validate Inputs
        if (!ingredients || !Array.isArray(ingredients) || ingredients.length === 0) {
            throw new Error('No ingredients provided')
        }

        const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY')
        if (!GROQ_API_KEY) {
            throw new Error('Missing GROQ_API_KEY')
        }

        // 3. Call Groq API with Llama model
        const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${GROQ_API_KEY}`,
            },
            body: JSON.stringify({
                model: 'llama-3.3-70b-versatile',
                messages: [{
                    role: 'user',
                    content: `You are a helpful chef. Generate a recipe based on these ingredients: ${ingredients.join(', ')}. 
              Return strictly valid JSON (no markdown formatting, no backticks) with this schema:
              { "title": "Recipe Name", "description": "Brief description", "ingredients": ["List of ingredients with quantities"], "instructions": ["Step 1", "Step 2"], "cooking_time": "Time in minutes" }`
                }],
                temperature: 0.7,
            }),
        })

        const data = await response.json()

        if (data.error) {
            throw new Error(data.error.message)
        }

        // 4. Extract text from Groq response
        let recipeContent = data.choices?.[0]?.message?.content;

        if (!recipeContent) {
            throw new Error('No content returned from Groq');
        }

        // Cleanup potential markdown if Gemini adds it despite instructions
        recipeContent = recipeContent.replace(/```json/g, '').replace(/```/g, '').trim();

        const recipeJson = JSON.parse(recipeContent);

        return new Response(
            JSON.stringify(recipeJson),
            { headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' } },
        )
    } catch (error) {
        console.error(error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' } },
        )
    }
})
