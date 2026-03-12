import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { JWT } from 'https://esm.sh/google-auth-library@9'

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', {
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
            }
        })
    }

    try {
        const { event, recipient_user_id, title, body } = await req.json()

        // Initialize Supabase Client
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 1. Fetch the user's FCM token(s)
        const { data: tokens, error: tokenError } = await supabaseClient
            .from('fcm_tokens')
            .select('token')
            .eq('user_id', recipient_user_id)

        if (tokenError || !tokens || tokens.length === 0) {
            console.log(`No FCM token found for user ${recipient_user_id}`)
            return new Response(JSON.stringify({ error: 'User does not have a registered device token' }), { headers: { 'Content-Type': 'application/json' }, status: 400 })
        }

        // 2. Generate Google OAuth2 Token from Service Account
        const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')
        let privateKey = Deno.env.get('FCM_PRIVATE_KEY')
        const projectId = Deno.env.get('FCM_PROJECT_ID')

        if (!clientEmail || !privateKey || !projectId) {
            throw new Error("Missing FCM credentials in Supabase Edge Function secrets")
        }

        privateKey = privateKey.replace(/\\n/g, '\n')

        const jwtClient = new JWT({
            email: clientEmail,
            key: privateKey,
            scopes: ['https://www.googleapis.com/auth/cloud-platform'],
        })

        const accessTokenData = await jwtClient.getAccessToken()
        const accessToken = accessTokenData.token

        // 3. Send Notification via FCM HTTP v1 API
        const responses = await Promise.all(
            tokens.map(async (t) => {
                const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        Authorization: `Bearer ${accessToken}`,
                    },
                    body: JSON.stringify({
                        message: {
                            token: t.token,
                            notification: { title: title, body: body },
                            data: { event_type: event, click_action: 'FLUTTER_NOTIFICATION_CLICK' }
                        }
                    }),
                })

                return await fcmResponse.json()
            })
        )

        return new Response(JSON.stringify({ success: true, fcm_responses: responses }), { headers: { 'Content-Type': 'application/json' } })

    } catch (error: any) {
        console.error(error)
        return new Response(JSON.stringify({ error: error.message }), { headers: { 'Content-Type': 'application/json' }, status: 400 })
    }
})
