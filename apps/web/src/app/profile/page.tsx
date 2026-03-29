'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import type { Profile } from '@/lib/types';
import { HR_ZONES } from '@/lib/utils/ftp';
import { wattsToPaceTenths, paceTenthsToWatts, formatWatts } from '@/lib/utils/ftp';
import { formatPace, parsePace } from '@/lib/utils/format';
import { Save, Loader2, LogOut, Link as LinkIcon, Unlink } from 'lucide-react';

export default function ProfilePage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [ftpPaceStr, setFtpPaceStr] = useState('');
  const [ftpWatts, setFtpWatts] = useState<number | null>(null);
  const [maxHr, setMaxHr] = useState<number | null>(null);
  const [c2UserId, setC2UserId] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createSupabaseBrowser();

    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) {
        router.push('/auth/login');
        return;
      }
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
  }, [router]);

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
    setSuccess(false);
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
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
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
      {success && (
        <div className="mb-6 rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-400">
          Profile saved successfully.
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
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-sm text-emerald-400">
              <LinkIcon className="h-4 w-4" />
              Connected (ID: {c2UserId})
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
          <a
            href="/api/c2/auth"
            className="flex items-center justify-center gap-2 rounded-lg border border-gray-700 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-gray-800"
          >
            <LinkIcon className="h-4 w-4" />
            Connect to C2 Logbook
          </a>
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
