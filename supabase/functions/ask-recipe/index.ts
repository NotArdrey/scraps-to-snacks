import "jsr:@supabase/functions-js/edge-runtime.d.ts"

console.log("Ask Recipe Function Loaded")

Deno.serve(async (req) => {
    // Handle Preflight (CORS)
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

        const { question, recipe } = await req.json()

        // Validate Inputs
        if (!question || typeof question !== 'string') {
            throw new Error('No question provided')
        }

        if (!recipe || !recipe.title) {
            throw new Error('No recipe provided')
        }

        const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY')
        if (!GROQ_API_KEY) {
            throw new Error('Missing GROQ_API_KEY')
        }

        // Build context about the recipe
        const recipeContext = `
Recipe: ${recipe.title}
Description: ${recipe.description}
Cooking Time: ${recipe.cookingTime}
Ingredients: ${recipe.ingredients?.join(', ') || 'Not specified'}
Instructions: ${recipe.instructions?.map((step: string, i: number) => `${i + 1}. ${step}`).join('\n') || 'Not specified'}
        `.trim();

        // Call Groq API with Llama model
        const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${GROQ_API_KEY}`,
            },
            body: JSON.stringify({
                model: 'llama-3.3-70b-versatile',
                messages: [
                    {
                        role: 'system',
                        content: `You are a helpful and friendly cooking assistant. You help users with questions about cooking recipes. 
Be concise but thorough in your answers. Provide practical tips and suggestions.
If asked about substitutions, consider dietary restrictions and what might be commonly available.
If asked about technique, be specific and helpful for beginners.

Here is the recipe the user is asking about:

${recipeContext}`
                    },
                    {
                        role: 'user',
                        content: question
                    }
                ],
                temperature: 0.7,
                max_tokens: 500,
            }),
        })

        const data = await response.json()

        if (data.error) {
            throw new Error(data.error.message)
        }

        // Extract text from Groq response
        const answer = data.choices?.[0]?.message?.content;

        if (!answer) {
            throw new Error('No content returned from Groq');
        }

        return new Response(
            JSON.stringify({ answer }),
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
