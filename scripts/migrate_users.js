require('dotenv').config({ path: '../.env' });
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SERVICE_ACCOUNT_PATH = './serviceAccountKey.json';

// --- CONFIG ---
const INITIAL_DELAY_MS = 0; // 0 seconds (FAST MODE 🏎️)
const MAX_RETRIES = 5;
// --------------

async function migrateUsers() {
    console.log('🚀 Starting User Invite/Reset Script...');

    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseKey) {
        console.error('❌ Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
        process.exit(1);
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
        console.error(`❌ Error: ${SERVICE_ACCOUNT_PATH} not found.`);
        process.exit(1);
    }
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }

    console.log('📦 Fetching users from Firebase...');
    let users = [];
    let nextPageToken;
    try {
        do {
            const result = await admin.auth().listUsers(1000, nextPageToken);
            users = users.concat(result.users);
            nextPageToken = result.pageToken;
        } while (nextPageToken);
    } catch (e) {
        console.error("❌ Error fetching Firebase users:", e.message);
        process.exit(1);
    }

    console.log(`\n👥 Found ${users.length} users. Processing invites...`);

    let processedCount = 0;
    let skippedCount = 0;

    for (const user of users) {
        if (!user.email) {
            skippedCount++;
            continue;
        }

        process.stdout.write(`   Processing ${user.email}... `);

        let success = false;
        let attempts = 0;
        let currentDelay = INITIAL_DELAY_MS;

        while (!success && attempts < MAX_RETRIES) {
            attempts++;

            // 1. Try Invite
            const { data: inviteData, error: inviteError } = await supabase.auth.admin.inviteUserByEmail(user.email, {
                data: {
                    firebase_uid: user.uid,
                    full_name: user.displayName || '',
                }
            });

            if (!inviteError) {
                console.log(`✅ Invited!`);
                await updateDataOwnership(supabase, user.uid, inviteData.user.id);
                success = true;
            } else if (inviteError.message.includes('already has been registered') || inviteError.status === 422) {
                // 2. Try Reset Password (if exists)
                const { error: resetError } = await supabase.auth.resetPasswordForEmail(user.email);

                if (!resetError) {
                    console.log(`✅ Reset Sent!`);
                    success = true;
                } else {
                    if (resetError.message.includes('rate limit')) {
                        process.stdout.write(`⏳ Rate Limit (Attempt ${attempts}). Waiting ${currentDelay / 1000}s... `);
                        await new Promise(r => setTimeout(r, currentDelay));
                        currentDelay *= 2; // Exponential Backoff: 2s -> 4s -> 8s -> 16s...
                    } else {
                        console.log(`❌ Error: ${resetError.message}`);
                        break; // Non-rate-limit error, abort this user
                    }
                }
            } else {
                // Invite failed
                if (inviteError.message.includes('rate limit')) {
                    process.stdout.write(`⏳ Rate Limit (Attempt ${attempts}). Waiting ${currentDelay / 1000}s... `);
                    await new Promise(r => setTimeout(r, currentDelay));
                    currentDelay *= 2;
                } else {
                    console.log(`❌ Error: ${inviteError.message}`);
                    break;
                }
            }
        }

        // Base delay between users even on success
        await new Promise(resolve => setTimeout(resolve, 2000));
        processedCount++;
    }

    console.log(`\n🎉 Done! Processed: ${processedCount}, Skipped: ${skippedCount}`);
}

async function updateDataOwnership(supabase, oldId, newId) {
    await supabase.from('committees').update({ host_id: newId }).eq('host_id', oldId);
}

migrateUsers();
