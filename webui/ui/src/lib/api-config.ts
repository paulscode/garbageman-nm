/**
 * API Configuration
 * 
 * Provides the base URL for API requests.
 * In production (StartOS/Docker), uses relative paths so Next.js rewrites handle proxying.
 * In development, can use localhost or environment variable override.
 */

export const getApiBaseUrl = (): string => {
  // In browser: check for NEXT_PUBLIC_API_BASE first, otherwise use relative path
  // Relative path allows Next.js rewrites to proxy regardless of hostname
  if (typeof window !== 'undefined') {
    return process.env.NEXT_PUBLIC_API_BASE || '';
  }
  
  // Server-side: use environment variable or default
  return process.env.API_BASE_URL || 'http://localhost:8080';
};

export const API_BASE_URL = getApiBaseUrl();
