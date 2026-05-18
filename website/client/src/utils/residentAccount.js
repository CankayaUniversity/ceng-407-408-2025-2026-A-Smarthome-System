/** Resident row has any login record (new or legacy columns). */
export function residentHasLoginAccount(resident) {
    if (!resident) return false;
    // Do not use legacy user_id — it caused false "Invite sent" badges for non-admins.
    return Boolean(resident.auth_user_id || resident.account_email);
}

/**
 * Auth user id used for status lookup — only auth_user_id (not user_id).
 * user_id is a legacy column and is sometimes wrong; it made every card look "active".
 */
export function getResidentAuthUserId(resident) {
    if (!resident) return null;
    return resident.auth_user_id || null;
}

function isTruthyFlag(value) {
    return value === true || value === 'true';
}

/**
 * Account is fully usable: finished invite flow (password set) and has signed in.
 */
export function isResidentAccountActive(authStatus) {
    if (!authStatus) return false;
    if (isTruthyFlag(authStatus.force_password_change)) return false;
    return Boolean(authStatus.last_sign_in_at);
}

/**
 * UI badge for login state (_authStatus from get_auth_users_status RPC).
 */
export function getResidentAccountBadge(resident) {
    if (!residentHasLoginAccount(resident)) return null;

    const st = resident._authStatus;
    const email = resident.account_email;

    if (st) {
        if (isTruthyFlag(st.force_password_change)) {
            return {
                label: 'Awaiting setup',
                color: 'var(--amber-core)',
                icon: 'mail',
                title: email
                    ? `${email} must open the invite email and set their password before the account is active.`
                    : 'Invite sent — waiting for them to complete password setup.',
            };
        }

        if (!st.email_confirmed_at) {
            return {
                label: 'Awaiting email',
                color: 'var(--amber-core)',
                icon: 'mail',
                title: email
                    ? `Waiting for ${email} to confirm their email address.`
                    : 'Waiting for email confirmation.',
            };
        }

        if (!st.last_sign_in_at) {
            return {
                label: 'Setup pending',
                color: 'var(--cyan-core)',
                icon: 'clock',
                title: email
                    ? `${email} has not signed in yet.`
                    : 'Email confirmed — waiting for first sign-in.',
            };
        }

        return {
            label: 'Account active',
            color: 'var(--jade-core)',
            icon: 'check',
            title: email
                ? `${email} can sign in to their dashboard.`
                : 'Login account is active.',
        };
    }

    // Auth status not loaded (RPC failed or skipped) — avoid misleading "Invite sent".
    return null;
}

/** Attach _authStatus from admin RPC (no-op if no auth ids). */
export async function attachResidentAuthStatus(supabase, residents) {
    if (!residents?.length) return residents;

    const userIds = [...new Set(
        residents.map(getResidentAuthUserId).filter(Boolean),
    )];
    if (userIds.length === 0) return residents;

    const { data, error } = await supabase.rpc('get_auth_users_status', { user_ids: userIds });
    if (error) {
        console.warn('get_auth_users_status:', error.message);
        return residents;
    }

    const byId = new Map((data || []).map(row => [row.user_id, row]));

    return residents.map(r => {
        const uid = getResidentAuthUserId(r);
        return uid ? { ...r, _authStatus: byId.get(uid) ?? null } : r;
    });
}
