/**
 * Architecture Detection and Validation
 * ======================================
 * Utilities for detecting system architecture and validating artifact compatibility.
 */

export type Architecture = 'x86_64' | 'aarch64' | 'unknown';

/**
 * Get the current system architecture from environment
 */
export function getSystemArchitecture(): Architecture {
  const arch = process.env.HOST_ARCH || 'unknown';
  if (arch === 'x86_64' || arch === 'aarch64') {
    return arch as Architecture;
  }
  return 'unknown';
}

/**
 * Detect architecture from binary filename
 * Examples:
 *   bitcoind-gm -> x86_64 (default)
 *   bitcoind-gm-aarch64 -> aarch64
 *   bitcoind-knots -> x86_64 (default)
 *   bitcoind-knots-aarch64 -> aarch64
 */
export function detectBinaryArchitecture(filename: string): Architecture {
  if (filename.includes('-aarch64') || filename.includes('_aarch64')) {
    return 'aarch64';
  }
  if (filename.includes('-x86_64') || filename.includes('_x86_64')) {
    return 'x86_64';
  }
  // Default to x86_64 for backward compatibility (most GitHub releases use no suffix for x86_64)
  return 'x86_64';
}

/**
 * Check if an artifact architecture is compatible with the system
 */
export function isArchitectureCompatible(
  artifactArch: Architecture,
  systemArch: Architecture = getSystemArchitecture()
): boolean {
  // Unknown architectures are considered incompatible
  if (artifactArch === 'unknown' || systemArch === 'unknown') {
    return false;
  }
  return artifactArch === systemArch;
}

/**
 * Get architecture-specific binary names for GitHub releases
 */
export function getExpectedBinaryNames(arch: Architecture): {
  bitcoindGm: string[];
  bitcoinCliGm: string[];
  bitcoindKnots: string[];
  bitcoinCliKnots: string[];
} {
  if (arch === 'aarch64') {
    return {
      bitcoindGm: ['bitcoind-gm-aarch64', 'bitcoind-gm_aarch64'],
      bitcoinCliGm: ['bitcoin-cli-gm-aarch64', 'bitcoin-cli-gm_aarch64'],
      bitcoindKnots: ['bitcoind-knots-aarch64', 'bitcoind-knots_aarch64'],
      bitcoinCliKnots: ['bitcoin-cli-knots-aarch64', 'bitcoin-cli-knots_aarch64'],
    };
  }
  
  // x86_64 - check both with and without suffix for backward compatibility
  return {
    bitcoindGm: ['bitcoind-gm', 'bitcoind-gm-x86_64', 'bitcoind-gm_x86_64'],
    bitcoinCliGm: ['bitcoin-cli-gm', 'bitcoin-cli-gm-x86_64', 'bitcoin-cli-gm_x86_64'],
    bitcoindKnots: ['bitcoind-knots', 'bitcoind-knots-x86_64', 'bitcoind-knots_x86_64'],
    bitcoinCliKnots: ['bitcoin-cli-knots', 'bitcoin-cli-knots-x86_64', 'bitcoin-cli-knots_x86_64'],
  };
}

/**
 * Normalize binary filename by removing architecture suffix
 * Example: bitcoind-gm-aarch64 -> bitcoind-gm
 */
export function normalizeBinaryFilename(filename: string): string {
  return filename
    .replace(/-aarch64$/, '')
    .replace(/_aarch64$/, '')
    .replace(/-x86_64$/, '')
    .replace(/_x86_64$/, '');
}

/**
 * Get architecture display name
 */
export function getArchitectureDisplayName(arch: Architecture): string {
  switch (arch) {
    case 'x86_64':
      return 'x86_64 (Intel/AMD 64-bit)';
    case 'aarch64':
      return 'aarch64 (ARM 64-bit)';
    case 'unknown':
      return 'Unknown';
  }
}
