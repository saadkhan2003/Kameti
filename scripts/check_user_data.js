
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '../.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkData(userId) {
    console.log(`🔍 Checking data for user: ${userId}`);

    const { data: committees, error } = await supabase
        .from('committees')
        .select('id, name, host_id')
        .eq('host_id', userId);

    if (error) {
        console.error('Error fetching committees:', error);
        return;
    }

    if (committees.length === 0) {
        console.log('❌ No committees found for this user.');
    } else {
        console.log(`✅ Found ${committees.length} committees:`);
        committees.forEach(c => console.log(`- ${c.name} (${c.id})`));
    }
}

// User ID found in previous step
const TARGET_USER_ID = 'fae820cc-4411-4199-afed-83fb3612146d';
checkData(TARGET_USER_ID);
