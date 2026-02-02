
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '../.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

async function verifyUser(email) {
    console.log(`🔍 Looking up user: ${email}`);

    // 1. List users to find the ID
    const { data: { users }, error } = await supabase.auth.admin.listUsers();

    if (error) {
        console.error('Error listing users:', error);
        return;
    }

    const user = users.find(u => u.email.toLowerCase() === email.toLowerCase());

    if (!user) {
        console.error(`❌ User not found: ${email}`);
        console.log('Available users:', users.map(u => u.email).join(', '));
        return;
    }

    console.log(`✅ Found user: ${user.id}`);
    console.log(`Current Status: ${user.email_confirmed_at ? 'Verified' : 'Unverified'}`);

    if (user.email_confirmed_at) {
        console.log('User is already verified.');
        return;
    }

    // 2. Update user to verify email
    console.log('⚡ Manually verifying email...');
    const { data, error: updateError } = await supabase.auth.admin.updateUserById(
        user.id,
        { email_confirm: true }
    );

    if (updateError) {
        console.error('Error updating user:', updateError);
    } else {
        console.log(`🎉 SUCCESS! User ${email} is now VERIFIED.`);
        console.log('You can now log in with the new password you set during signup.');
    }
}

// Get email from command line arg
const email = process.argv[2];
if (!email) {
    console.log('Usage: node verify_user.js <email>');
    process.exit(1);
}

verifyUser(email);
