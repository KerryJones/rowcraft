import { describe, expect, it } from 'vitest';
import { HANDOFF_MAX_AGE_MS, isHandoffExpired } from '../oauth-handoff';

describe('isHandoffExpired', () => {
  const now = new Date('2026-07-03T12:00:00Z');

  it('returns false for a fresh handoff', () => {
    expect(isHandoffExpired('2026-07-03T11:59:00Z', now)).toBe(false);
  });

  it('returns false just inside the max age', () => {
    const created = new Date(now.getTime() - HANDOFF_MAX_AGE_MS + 1000);
    expect(isHandoffExpired(created.toISOString(), now)).toBe(false);
  });

  it('returns true just past the max age', () => {
    const created = new Date(now.getTime() - HANDOFF_MAX_AGE_MS - 1000);
    expect(isHandoffExpired(created.toISOString(), now)).toBe(true);
  });

  it('returns true for an unparseable timestamp', () => {
    expect(isHandoffExpired('not-a-date', now)).toBe(true);
  });

  it('returns true for a handoff hours old', () => {
    expect(isHandoffExpired('2026-07-03T08:00:00Z', now)).toBe(true);
  });
});
