import { NextRequest, NextResponse } from 'next/server';
import { createOAuthHandoff } from '@/lib/oauth-handoff';

export async function POST(request: NextRequest): Promise<NextResponse> {
  return createOAuthHandoff(request, 'c2');
}
