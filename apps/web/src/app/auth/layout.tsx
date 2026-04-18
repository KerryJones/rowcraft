import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Login — RowCraft',
  description: 'Sign in to your RowCraft account.',
};

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
