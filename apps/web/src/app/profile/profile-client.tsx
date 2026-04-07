'use client';

import { useState, useEffect, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import type { Profile } from '@/lib/types';
import { HR_ZONES } from '@/lib/utils/ftp';
import { wattsToPaceTenths, paceTenthsToWatts, formatWatts } from '@/lib/utils/ftp';
import { formatPace, parsePace } from '@/lib/utils/format';
import { Save, Loader2, LogOut, Link as LinkIcon, Unlink, CheckCircle2 } from 'lucide-react';

const C2_ERROR_MESSAGES: Record<string, string> = {
  c2_oauth_failed: 'Concept2 authorization failed. Please try again.',
  c2_token_exchange_failed: 'Failed to connect to Concept2. Please try again.',
  c2_user_fetch_failed: 'Could not retrieve your Concept2 account. Please try again.',
  c2_session_expired: 'Your session expired. Please sign in and try again.',
  c2_save_failed: 'Failed to save Concept2 connection. Please try again.',
};

function ProfilePageInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  // Read C2 OAuth callback params from URL and initialize state
  const c2Param = searchParams.get('c2');
  const errorParam = searchParams.get('error');
  const initialC2Success = c2Param === 'connected' ? 'Concept2 Logbook connected successfully!' : null;
  const initialC2Error = errorParam ? (C2_ERROR_MESSAGES[errorParam] ?? 'An error occurred connecting to Concept2.') : null;

  const [error, setError] = useState<string | null>(initialC2Error);
  const [successMessage, setSuccessMessage] = useState<string | null>(initialC2Success);

  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [ftpPaceStr, setFtpPaceStr] = useState('');
  const [ftpWatts, setFtpWatts] = useState<number | null>(null);
  const [maxHr, setMaxHr] = useState<number | null>(null);
  const [c2UserId, setC2UserId] = useState<string | null>(null);

  // Strip C2 OAuth params from URL and auto-dismiss success banner
  useEffect(() => {
    if (c2Param || errorParam) {
      router.replace('/profile', { scroll: false });
    }
    if (initialC2Success) {
      const timer = setTimeout(() => setSuccessMessage(null), 5000);
      return () => clearTimeout(timer);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps -- run once on mount to strip OAuth params from URL

  useEffect(() => {
    const supabase = createSupabaseBrowser();

    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      setEmail(data.user.email ?? '');

      const { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', data.user.id)
        .single();

      if (profile) {
        const p = profile as Profile;
        setDisplayName(p.display_name ?? '');
        setC2UserId(p.c2_user_id);
        setMaxHr(p.max_heart_rate);
        if (p.current_ftp_watts) {
          setFtpWatts(p.current_ftp_watts);
          const pace = wattsToPaceTenths(p.current_ftp_watts);
          setFtpPaceStr(formatPace(pace));
        }
      }

      setLoading(false);
    }).catch(() => {
      setError('Failed to load profile');
      setLoading(false);
    });
  }, []);

  function handleFtpPaceBlur() {
    if (!ftpPaceStr.trim()) {
      setFtpWatts(null);
      return;
    }
    const tenths = parsePace(ftpPaceStr);
    if (tenths !== null) {
      setFtpWatts(paceTenthsToWatts(tenths));
    } else {
      // Reset to current watts
      if (ftpWatts) {
        setFtpPaceStr(formatPace(wattsToPaceTenths(ftpWatts)));
      } else {
        setFtpPaceStr('');
      }
    }
  }

  async function handleSave() {
    setError(null);
    setSuccessMessage(null);
    setSaving(true);

    try {
    const supabase = createSupabaseBrowser();
    const { data: user } = await supabase.auth.getUser();
    if (!user.user) {
      setError('Not authenticated');
      return;
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        display_name: displayName.trim() || null,
        current_ftp_watts: ftpWatts,
        max_heart_rate: maxHr,
      })
      .eq('id', user.user.id);

    if (updateError) {
      setError(updateError.message);
    } else {
      setSuccessMessage('Profile saved successfully.');
      setTimeout(() => setSuccessMessage(null), 3000);
    }
    } finally {
      setSaving(false);
    }
  }

  async function handleSignOut() {
    const supabase = createSupabaseBrowser();
    await supabase.auth.signOut();
    router.push('/');
    router.refresh();
  }

  async function handleC2Disconnect() {
    const supabase = createSupabaseBrowser();
    const { data: user } = await supabase.auth.getUser();
    if (!user.user) return;

    const { error } = await supabase
      .from('profiles')
      .update({ c2_user_id: null, c2_access_token: null, c2_refresh_token: null })
      .eq('id', user.user.id);

    if (error) {
      setError('Failed to disconnect C2 Logbook');
      return;
    }
    setC2UserId(null);
  }

  // HR zone calculator
  const hrZones = maxHr
    ? HR_ZONES.map((zone, i) => ({
        zone: i + 1,
        label: zone.label,
        min: Math.round(maxHr * (zone.minPct / 100)),
        max: Math.round(maxHr * (zone.maxPct / 100)),
      }))
    : [];

  if (loading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="mb-8 text-3xl font-bold text-white">Profile</h1>

      {error && (
        <div className="mb-6 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-400">
          {error}
        </div>
      )}
      {successMessage && (
        <div className="mb-6 rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-400">
          {successMessage}
        </div>
      )}

      <div className="space-y-6 rounded-xl border border-gray-800 bg-gray-900 p-6">
        {/* Display Name */}
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Display Name</label>
          <input
            type="text"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="Your name"
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        {/* Email (disabled) */}
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Email</label>
          <input
            type="email"
            value={email}
            disabled
            className="w-full rounded-lg border border-gray-700 bg-gray-800/50 px-4 py-2.5 text-gray-500"
          />
        </div>

        {/* FTP Pace */}
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">
            FTP Pace (m:ss/500m)
            {ftpWatts !== null && (
              <span className="ml-2 font-normal text-gray-500">= {formatWatts(ftpWatts)}</span>
            )}
          </label>
          <input
            type="text"
            value={ftpPaceStr}
            onChange={(e) => setFtpPaceStr(e.target.value)}
            onBlur={handleFtpPaceBlur}
            placeholder="2:00"
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        {/* Max HR */}
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Max Heart Rate (bpm)</label>
          <input
            type="number"
            min={100}
            max={250}
            value={maxHr ?? ''}
            onChange={(e) => setMaxHr(e.target.value ? parseInt(e.target.value) : null)}
            placeholder="190"
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        {/* HR Zone Calculator */}
        {hrZones.length > 0 && (
          <div>
            <h3 className="mb-2 text-sm font-medium text-gray-400">HR Zones</h3>
            <div className="space-y-1.5">
              {hrZones.map((zone) => (
                <div
                  key={zone.zone}
                  className="flex items-center justify-between rounded-lg bg-gray-800/50 px-3 py-2"
                >
                  <span className="text-sm text-white">
                    Z{zone.zone} {zone.label}
                  </span>
                  <span className="text-sm text-gray-400">
                    {zone.min}–{zone.max} bpm
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Save */}
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-lg bg-blue-600 py-2.5 font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
        >
          {saving ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          {saving ? 'Saving...' : 'Save Profile'}
        </button>
      </div>

      {/* C2 Logbook */}
      <div className="mt-6 rounded-xl border border-gray-800 bg-gray-900 p-6">
        <h2 className="mb-4 text-lg font-semibold text-white">Concept2 Logbook</h2>
        {c2UserId ? (
          <div className="space-y-3">
            <div className="flex items-center gap-3">
              <CheckCircle2 className="h-6 w-6 shrink-0 text-emerald-400" />
              <div>
                <p className="font-medium text-emerald-400">Connected to Concept2 Logbook</p>
                <p className="text-sm text-gray-500">Account ID: {c2UserId}</p>
              </div>
            </div>
            <button
              type="button"
              onClick={handleC2Disconnect}
              className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-700 px-3 py-2 text-sm text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
            >
              <Unlink className="h-4 w-4" />
              Disconnect
            </button>
          </div>
        ) : (
          <div className="space-y-3">
            <p className="text-sm text-gray-400">
              Connect your Concept2 Logbook to automatically sync completed workouts.
            </p>
            <a
              href="/api/c2/auth"
              className="flex items-center justify-center gap-2 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
            >
              <LinkIcon className="h-4 w-4" />
              Connect to C2 Logbook
            </a>
          </div>
        )}
      </div>

      {/* Sign out */}
      <button
        type="button"
        onClick={handleSignOut}
        className="mt-6 flex w-full cursor-pointer items-center justify-center gap-2 rounded-lg border border-gray-700 py-2.5 text-sm font-medium text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
      >
        <LogOut className="h-4 w-4" />
        Sign Out
      </button>
    </div>
  );
}

export default function ProfilePage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-[60vh] items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
        </div>
      }
    >
      <ProfilePageInner />
    </Suspense>
  );
}
