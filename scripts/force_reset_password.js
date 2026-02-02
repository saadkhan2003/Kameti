
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '../.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function resetPassword(email, newPassword) {
    console.log(`🔍 Looking up user: ${email}`);

    const { data: { users }, error } = await supabase.auth.admin.listUsers();

    if (error) {
        console.error('Error listing users:', error);
        return;
    }

    const user = users.find(u => u.email.toLowerCase() === email.toLowerCase());

    if (!user) {
        console.error(`❌ User not found: ${email}`);
        return;
    }

    console.log(`✅ Found user: ${user.id}`);
    console.log('⚡ Updating password...');

    const { data, error: updateError } = await supabase.auth.admin.updateUserById(
        user.id,
        { password: newPassword }
    );

    if (updateError) {
        console.error('❌ Error updating password:', updateError);
    } else {
        console.log(`🎉 SUCCESS! Password for ${email} has been reset.`);
        console.log(`🔑 New Password: ${newPassword}`);
    }
}

// Args
const email = process.argv[2];
const newPassword = process.argv[3];

if (!email || !newPassword) {
    console.log('Usage: node force_reset_password.js <email> <new_password>');
    process.exit(1);
}

resetPassword(email, newPassword);
