'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import type { User } from '@supabase/supabase-js';
import { cn } from '@/lib/utils/cn';
import { Menu, X, LogOut, User as UserIcon } from 'lucide-react';

export function Header() {
  const [user, setUser] = useState<User | null>(null);
  const [mobileOpen, setMobileOpen] = useState(false);
  const pathname = usePathname();
  const router = useRouter();
  const supabase = createSupabaseBrowser();

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setUser(data.user));
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_, session) => {
      setUser(session?.user ?? null);
    });
    return () => subscription.unsubscribe();
  }, [supabase]);

  const isLoggedIn = !!user;

  const navLinks = isLoggedIn
    ? [
        { href: '/workouts', label: 'Workouts' },
        { href: '/plans', label: 'Plans' },
        { href: '/builder', label: 'Builder' },
        { href: '/history', label: 'History' },
      ]
    : [
        { href: '/workouts', label: 'Workouts' },
        { href: '/plans', label: 'Plans' },
      ];

  function isActive(href: string) {
    return pathname === href || pathname.startsWith(href + '/');
  }

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.push('/');
    router.refresh();
  }

  return (
    <nav className="sticky top-0 z-50 border-b border-gray-800 bg-gray-950/95 backdrop-blur-sm">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2 text-xl font-bold text-white">
          <svg viewBox="0 0 120 80" fill="none" className="h-7 w-auto" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="rc-gold" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#FFD700"/>
                <stop offset="50%" stopColor="#FFC107"/>
                <stop offset="100%" stopColor="#B8860B"/>
              </linearGradient>
            </defs>
            <path d="M8 8h28c11 0 20 9 20 20s-9 20-20 20H28l24 24"
                  stroke="url(#rc-gold)" strokeWidth="7" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
            <line x1="8" y1="8" x2="8" y2="72" stroke="url(#rc-gold)" strokeWidth="7" strokeLinecap="round"/>
            <path d="M112 20c-4-8-12-12-22-12-16 0-28 14-28 32s12 32 28 32c10 0 18-4 22-12"
                  stroke="url(#rc-gold)" strokeWidth="7" strokeLinecap="round" fill="none"/>
          </svg>
          RowCraft
        </Link>

        {/* Desktop nav */}
        <div className="hidden items-center gap-1 md:flex">
          {navLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={cn(
                'rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                isActive(link.href)
                  ? 'bg-gray-800 text-white'
                  : 'text-gray-400 hover:bg-gray-800/50 hover:text-white',
              )}
            >
              {link.label}
            </Link>
          ))}

          {isLoggedIn ? (
            <div className="ml-2 flex items-center gap-1 border-l border-gray-800 pl-3">
              <Link
                href="/profile"
                className={cn(
                  'rounded-lg p-2 text-sm transition-colors',
                  isActive('/profile')
                    ? 'bg-gray-800 text-white'
                    : 'text-gray-400 hover:bg-gray-800/50 hover:text-white',
                )}
                title="Profile"
              >
                <UserIcon className="h-4 w-4" />
              </Link>
              <button
                onClick={handleSignOut}
                className="rounded-lg p-2 text-gray-400 transition-colors hover:bg-gray-800/50 hover:text-white cursor-pointer"
                title="Sign out"
              >
                <LogOut className="h-4 w-4" />
              </button>
            </div>
          ) : (
            <Link
              href="/auth/login"
              className="ml-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
            >
              Login
            </Link>
          )}
        </div>

        {/* Mobile hamburger */}
        <button
          className="rounded-lg p-2 text-gray-400 hover:bg-gray-800 hover:text-white md:hidden cursor-pointer"
          onClick={() => setMobileOpen(!mobileOpen)}
          aria-label="Toggle menu"
        >
          {mobileOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {/* Mobile menu */}
      {mobileOpen && (
        <div className="border-t border-gray-800 bg-gray-950 md:hidden">
          <div className="space-y-1 px-4 py-3">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setMobileOpen(false)}
                className={cn(
                  'block rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                  isActive(link.href)
                    ? 'bg-gray-800 text-white'
                    : 'text-gray-400 hover:bg-gray-800/50 hover:text-white',
                )}
              >
                {link.label}
              </Link>
            ))}
            {isLoggedIn ? (
              <>
                <Link
                  href="/profile"
                  onClick={() => setMobileOpen(false)}
                  className="block rounded-lg px-3 py-2 text-sm font-medium text-gray-400 hover:bg-gray-800/50 hover:text-white"
                >
                  Profile
                </Link>
                <button
                  onClick={() => {
                    setMobileOpen(false);
                    handleSignOut();
                  }}
                  className="block w-full rounded-lg px-3 py-2 text-left text-sm font-medium text-gray-400 hover:bg-gray-800/50 hover:text-white cursor-pointer"
                >
                  Sign Out
                </button>
              </>
            ) : (
              <Link
                href="/auth/login"
                onClick={() => setMobileOpen(false)}
                className="block rounded-lg px-3 py-2 text-sm font-medium text-blue-400 hover:bg-gray-800/50 hover:text-white"
              >
                Login
              </Link>
            )}
          </div>
        </div>
      )}
    </nav>
  );
}
