
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '../.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkDetails(userId) {
    console.log(`🔍 Checking details for user: ${userId}`);

    const { data: committees, error } = await supabase
        .from('committees')
        .select('*') // Get all fields
        .eq('host_id', userId);

    if (error) {
        console.error('Error fetching:', error);
        return;
    }

    committees.forEach(c => {
        console.log(`\n📋 Committee: ${c.name} (${c.id})`);
        console.log(`   is_archived: ${c.is_archived} (Type: ${typeof c.is_archived})`);
        console.log(`   is_active:   ${c.is_active}   (Type: ${typeof c.is_active})`);
        console.log(`   host_id:     ${c.host_id}`);
    });
}

const TARGET_USER_ID = 'fae820cc-4411-4199-afed-83fb3612146d';
checkDetails(TARGET_USER_ID);
