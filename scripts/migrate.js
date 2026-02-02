require('dotenv').config({ path: '../.env' });
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SERVICE_ACCOUNT_PATH = './serviceAccountKey.json';

// Track valid IDs to ensure referential integrity
const validCommitteeIds = new Set();
const validMemberIds = new Set();

async function migrate() {
    console.log('🚀 Starting Migration: Firestore -> Supabase');

    if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
        console.error(`❌ Error: ${SERVICE_ACCOUNT_PATH} not found.`);
        process.exit(1);
    }

    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    const db = admin.firestore();
    console.log('✅ Firebase initialized');

    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseKey) {
        console.error('❌ Error: Missing SUPABASE_URL or SUPABASE_KEY in .env');
        process.exit(1);
    }

    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log('✅ Supabase initialized');

    // Order matters! Committees -> Members -> Payments
    await migrateCollection(db, supabase, 'committees', 'committees');
    await migrateCollection(db, supabase, 'members', 'members');
    await migrateCollection(db, supabase, 'payments', 'payments');

    console.log('🎉 MIGRATION COMPLETE!');
}

async function migrateCollection(db, supabase, firestoreCol, supabaseTable) {
    console.log(`\n📦 Migrating ${firestoreCol}...`);

    const snapshot = await db.collection(firestoreCol).get();
    if (snapshot.empty) {
        console.log(`   -> No documents in ${firestoreCol}`);
        return;
    }

    const records = [];
    let skippedCount = 0;

    snapshot.forEach(doc => {
        const data = doc.data();
        data.id = doc.id;

        // Convert Timestamps
        for (const key in data) {
            if (data[key] && typeof data[key].toDate === 'function') {
                data[key] = data[key].toDate().toISOString();
            }
        }

        const transformed = transformToSnakeCase(data, supabaseTable);

        // --- INTEGRITY CHECKS ---
        if (supabaseTable === 'members') {
            if (!validCommitteeIds.has(transformed.committee_id)) {
                // console.warn(`   ⚠️ Skipping orphan member ${transformed.id} (committee ${transformed.committee_id} missing)`);
                skippedCount++;
                return; // Skip this record
            }
        }

        if (supabaseTable === 'payments') {
            if (!validMemberIds.has(transformed.member_id)) {
                // console.warn(`   ⚠️ Skipping orphan payment ${transformed.id} (member ${transformed.member_id} missing)`);
                skippedCount++;
                return; // Skip
            }
        }
        // ------------------------

        records.push(transformed);

        // Track IDs for next steps
        if (supabaseTable === 'committees') validCommitteeIds.add(transformed.id);
        if (supabaseTable === 'members') validMemberIds.add(transformed.id);
    });

    if (skippedCount > 0) {
        console.log(`   ⚠️ Skipped ${skippedCount} orphaned records (referenced parent missing).`);
    }
    console.log(`   -> Found ${records.length} valid records. Uploading...`);

    if (records.length === 0) {
        console.log('   -> Nothing to upload.');
        return;
    }

    // Batch insert (chunking might be needed for 1300+ records, Supabase limit is usually huge but better safe)
    // Let's do chunks of 500 just in case
    const chunkSize = 500;
    for (let i = 0; i < records.length; i += chunkSize) {
        const chunk = records.slice(i, i + chunkSize);
        const { error } = await supabase
            .from(supabaseTable)
            .upsert(chunk, { onConflict: 'id' });

        if (error) {
            console.error(`   ❌ Error uploading ${supabaseTable} (chunk ${i}):`, error);
        } else {
            console.log(`   ✅ Uploaded chunk ${i} - ${i + chunk.length}`);
        }
    }
}

function transformToSnakeCase(data, table) {
    const newData = { ...data };

    // Rename helper
    const rename = (oldKey, newKey) => {
        if (newData[oldKey] !== undefined) {
            newData[newKey] = newData[oldKey];
            delete newData[oldKey];
        }
    };

    if (table === 'committees') {
        rename('contributionAmount', 'contribution_amount');
        rename('startDate', 'start_date');
        rename('hostId', 'host_id');
        rename('totalMembers', 'total_members');
        rename('createdAt', 'created_at');
        rename('isActive', 'is_active');
        rename('paymentIntervalDays', 'payment_interval_days');
        rename('isArchived', 'is_archived');
        rename('archivedAt', 'archived_at');

        if (newData['code']) delete newData['code'];

        if (newData['total_cycles'] === undefined || newData['total_cycles'] === null) {
            const members = newData['total_members'] !== undefined ? newData['total_members'] : 0;
            newData['total_cycles'] = members > 0 ? members : 10;
        }
    }

    if (table === 'members') {
        rename('committeeId', 'committee_id');
        rename('payoutOrder', 'payout_order');
        rename('createdAt', 'created_at');
        rename('hasReceivedPayout', 'has_received_payout');
        rename('payoutDate', 'payout_date');
        rename('memberCode', 'member_code');
    }

    if (table === 'payments') {
        rename('memberId', 'member_id');
        rename('committeeId', 'committee_id');
        rename('isPaid', 'is_paid');
        rename('markedBy', 'marked_by');
        rename('markedAt', 'marked_at');
        rename('createdAt', 'created_at');

        if (!newData['date']) {
            if (newData['timestamp']) newData['date'] = newData['timestamp'];
            else if (newData['paymentDate']) newData['date'] = newData['paymentDate'];
            else newData['date'] = newData['created_at'] || new Date().toISOString();
        }
    }

    delete newData['updatedAt'];
    return newData;
}

migrate();
