
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '../.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !anonKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, anonKey);

async function checkAccess() {
    console.log('🔑 Logging in as user...');

    // Log in with the known credentials
    const { data: { session }, error: loginError } = await supabase.auth.signInWithPassword({
        email: 'msaad.official6@gmail.com',
        password: 'kameti123'
    });

    if (loginError) {
        console.error('❌ Login failed:', loginError.message);
        return;
    }

    console.log(`✅ Logged in as: ${session.user.email} (${session.user.id})`);
    console.log('🔍 Attempting to fetch committees via Anon Key (simulating App)...');

    const { data: committees, error } = await supabase
        .from('committees')
        .select('id, name')
        .eq('host_id', session.user.id);

    if (error) {
        console.error('❌ Error fetching:', error.message);
    } else if (committees.length === 0) {
        console.log('⚠️ Result: 0 committees found.');
        console.log('⛔ DIAGNOSIS: RLS is likely blocking the read operation.');
    } else {
        console.log(`✅ Result: Found ${committees.length} committees.`);
        console.log('✅ DIAGNOSIS: RLS seems fine. The issue might be in the App logic.');
    }
}

checkAccess();
