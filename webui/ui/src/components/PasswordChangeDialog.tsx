'use client';

import { useState, useEffect, useRef } from 'react';
import { API_BASE_URL } from '@/lib/api-config';

interface PasswordChangeDialogProps {
  isOpen: boolean;
  onPasswordChanged: (newToken: string) => void;
  onError: (message: string) => void;
}

export function PasswordChangeDialog({ isOpen, onPasswordChanged, onError }: PasswordChangeDialogProps) {
  const [currentPassword, setCurrentPassword] = useState('garbageman');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [isShaking, setIsShaking] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const newPasswordRef = useRef<HTMLInputElement>(null);

  // Auto-focus new password input when dialog appears
  useEffect(() => {
    if (isOpen && newPasswordRef.current) {
      newPasswordRef.current.focus();
    }
  }, [isOpen]);

  // Trigger shake animation
  const triggerShake = () => {
    setIsShaking(true);
    setTimeout(() => setIsShaking(false), 500);
  };

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validation
    if (!newPassword.trim()) {
      setError('New password required');
      triggerShake();
      return;
    }
    
    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters');
      triggerShake();
      return;
    }
    
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      triggerShake();
      return;
    }
    
    if (newPassword === 'garbageman') {
      setError('Cannot use default password');
      triggerShake();
      return;
    }

    setIsSubmitting(true);
    setError('');

    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/change-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          currentPassword,
          newPassword,
        }),
      });

      const data = await response.json();

      if (data.success && data.token) {
        onPasswordChanged(data.token);
      } else {
        setError(data.message || 'Failed to change password');
        triggerShake();
        setIsSubmitting(false);
      }
    } catch (error) {
      console.error('Password change error:', error);
      onError('Failed to connect to server');
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-80 backdrop-blur-sm">
      <div 
        className={`bg-bg1 border-2 border-accent p-8 max-w-md w-full mx-4 shadow-2xl shadow-accent/20 ${
          isShaking ? 'animate-shake' : ''
        }`}
      >
        <div className="mb-6 text-center">
          <div className="text-accent text-2xl font-mono font-bold mb-2">
            ⚠️ PASSWORD CHANGE REQUIRED
          </div>
          <div className="text-tx2 text-sm font-mono">
            Default password detected. Please set a new password to continue.
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="current-password" className="block text-tx3 text-sm font-mono mb-2">
              Current Password
            </label>
            <input
              id="current-password"
              type="password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className="w-full bg-bg0 border border-tx3 text-tx0 font-mono px-3 py-2 focus:outline-none focus:border-accent"
              placeholder="garbageman"
              disabled={isSubmitting}
            />
          </div>

          <div>
            <label htmlFor="new-password" className="block text-tx3 text-sm font-mono mb-2">
              New Password (min 8 characters)
            </label>
            <input
              ref={newPasswordRef}
              id="new-password"
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className="w-full bg-bg0 border border-tx3 text-tx0 font-mono px-3 py-2 focus:outline-none focus:border-accent"
              placeholder="Enter new password"
              disabled={isSubmitting}
            />
          </div>

          <div>
            <label htmlFor="confirm-password" className="block text-tx3 text-sm font-mono mb-2">
              Confirm New Password
            </label>
            <input
              id="confirm-password"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="w-full bg-bg0 border border-tx3 text-tx0 font-mono px-3 py-2 focus:outline-none focus:border-accent"
              placeholder="Confirm new password"
              disabled={isSubmitting}
            />
          </div>

          {error && (
            <div className="text-red-500 text-sm font-mono text-center">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={isSubmitting}
            className="w-full bg-accent hover:bg-acc-orange text-bg0 font-mono font-bold py-3 px-4 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? 'CHANGING PASSWORD...' : 'CHANGE PASSWORD'}
          </button>
        </form>

        <div className="mt-4 text-tx3 text-xs font-mono text-center">
          This change is permanent and cannot be undone.
        </div>
      </div>
    </div>
  );
}
