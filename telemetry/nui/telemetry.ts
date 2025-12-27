/**
 * Telemetry Client for NUI/Browser
 * Captures browser errors and forwards to Lua via fetchNui
 *
 * OPEN SOURCE - Part of dusa_bridge
 *
 * Usage in React apps:
 *   import { initTelemetry } from '@dusa_bridge/telemetry/nui/telemetry';
 *   initTelemetry({ resourceName: 'mechanic-spec' });
 *
 * Or copy this file to your web/src/utils/ folder and import from there.
 */

// ============================================
// Types
// ============================================

export interface TelemetryOptions {
  resourceName?: string;
  maxErrorsPerMinute?: number;
  enableConsoleIntercept?: boolean;
  enableUnhandledRejection?: boolean;
  enableUncaughtErrors?: boolean;
}

export interface NuiErrorData {
  message: string;
  stack?: string;
  source: 'uncaught' | 'console.error' | 'promise_rejection';
  location?: {
    source?: string;
    lineno?: number;
    colno?: number;
  };
  componentStack?: string;
  resourceName?: string;
  timestamp?: number;
}

export interface BreadcrumbData {
  category?: string;
  message: string;
  level?: 'trace' | 'debug' | 'info' | 'warning' | 'error' | 'fatal';
  params?: Record<string, unknown>;
}

// ============================================
// State
// ============================================

let isInitialized = false;
let resourceName = 'unknown';
let maxErrorsPerMinute = 10;
let errorCount = 0;
let lastResetTime = Date.now();

// Store original console.error
let originalConsoleError: typeof console.error | null = null;

// ============================================
// Utilities
// ============================================

/**
 * Get the parent resource name from FiveM
 */
function getResourceName(): string {
  if (typeof (window as any).GetParentResourceName === 'function') {
    return (window as any).GetParentResourceName();
  }
  return resourceName;
}

/**
 * Check if we're in a browser environment (dev mode)
 */
function isEnvBrowser(): boolean {
  return !(window as any).invokeNative;
}

/**
 * Rate limit check
 */
function shouldRateLimit(): boolean {
  const now = Date.now();

  // Reset counter every minute
  if (now - lastResetTime > 60000) {
    errorCount = 0;
    lastResetTime = now;
  }

  if (errorCount >= maxErrorsPerMinute) {
    return true;
  }

  errorCount++;
  return false;
}

/**
 * Send error to Lua via NUI callback
 */
async function sendError(data: NuiErrorData): Promise<void> {
  // Don't send in browser dev mode
  if (isEnvBrowser()) {
    console.warn('[Telemetry] Browser mode - error not sent:', data.message);
    return;
  }

  // Rate limit
  if (shouldRateLimit()) {
    return;
  }

  // Add metadata
  data.resourceName = data.resourceName || getResourceName();
  data.timestamp = Date.now();

  try {
    await fetch(`https://${getResourceName()}/dusa_bridge:telemetry:nuiError`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data),
    });
  } catch {
    // Silent fail - don't cause more errors
  }
}

/**
 * Send breadcrumb to Lua
 */
async function sendBreadcrumb(data: BreadcrumbData): Promise<void> {
  if (isEnvBrowser()) return;

  try {
    await fetch(`https://${getResourceName()}/dusa_bridge:telemetry:nuiBreadcrumb`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data),
    });
  } catch {
    // Silent fail
  }
}

// ============================================
// Error Handlers
// ============================================

/**
 * Handle uncaught errors (window.onerror)
 */
function handleUncaughtError(
  message: string | Event,
  source?: string,
  lineno?: number,
  colno?: number,
  error?: Error
): void {
  sendError({
    message: error?.message || String(message),
    stack: error?.stack,
    source: 'uncaught',
    location: { source, lineno, colno },
  });
}

/**
 * Handle unhandled promise rejections
 */
function handleUnhandledRejection(event: PromiseRejectionEvent): void {
  const error = event.reason;

  sendError({
    message: error?.message || String(error),
    stack: error?.stack,
    source: 'promise_rejection',
  });
}

/**
 * Create intercepted console.error
 */
function createConsoleErrorInterceptor(): typeof console.error {
  return function (...args: unknown[]): void {
    // Call original
    if (originalConsoleError) {
      originalConsoleError.apply(console, args);
    }

    // Format message
    const message = args
      .map((arg) => {
        if (arg instanceof Error) {
          return arg.message;
        }
        if (typeof arg === 'object') {
          try {
            return JSON.stringify(arg);
          } catch {
            return String(arg);
          }
        }
        return String(arg);
      })
      .join(' ');

    // Get stack if first arg is Error
    const stack = args[0] instanceof Error ? args[0].stack : undefined;

    sendError({
      message,
      stack,
      source: 'console.error',
    });
  };
}

// ============================================
// Public API
// ============================================

/**
 * Initialize telemetry error capture
 *
 * @example
 * ```ts
 * import { initTelemetry } from './telemetry';
 *
 * initTelemetry({
 *   resourceName: 'mechanic-spec',
 *   maxErrorsPerMinute: 10,
 *   enableConsoleIntercept: true,
 * });
 * ```
 */
export function initTelemetry(options: TelemetryOptions = {}): void {
  if (isInitialized) {
    console.warn('[Telemetry] Already initialized');
    return;
  }

  // Apply options
  resourceName = options.resourceName || 'unknown';
  maxErrorsPerMinute = options.maxErrorsPerMinute ?? 10;

  const enableUncaught = options.enableUncaughtErrors ?? true;
  const enableRejection = options.enableUnhandledRejection ?? true;
  const enableConsole = options.enableConsoleIntercept ?? true;

  // Set up uncaught error handler
  if (enableUncaught) {
    window.onerror = handleUncaughtError;
  }

  // Set up unhandled rejection handler
  if (enableRejection) {
    window.onunhandledrejection = handleUnhandledRejection;
  }

  // Intercept console.error
  if (enableConsole) {
    originalConsoleError = console.error;
    console.error = createConsoleErrorInterceptor();
  }

  isInitialized = true;

  if (!isEnvBrowser()) {
    console.log('[Telemetry] NUI error capture initialized');
  }
}

/**
 * Manually capture an error
 *
 * @example
 * ```ts
 * try {
 *   riskyOperation();
 * } catch (error) {
 *   captureError(error as Error, { operation: 'riskyOperation' });
 * }
 * ```
 */
export function captureError(
  error: Error,
  context?: Record<string, unknown>
): void {
  sendError({
    message: error.message,
    stack: error.stack,
    source: 'uncaught',
    componentStack: context ? JSON.stringify(context) : undefined,
  });
}

/**
 * Add a breadcrumb for context
 *
 * @example
 * ```ts
 * addBreadcrumb({
 *   category: 'UI',
 *   message: 'User clicked submit button',
 *   level: 'info',
 *   params: { formId: 'hire-form' },
 * });
 * ```
 */
export function addBreadcrumb(data: BreadcrumbData): void {
  sendBreadcrumb(data);
}

/**
 * Restore original console.error (cleanup)
 */
export function restoreConsole(): void {
  if (originalConsoleError) {
    console.error = originalConsoleError;
    originalConsoleError = null;
  }
}

/**
 * React Error Boundary helper
 * Use this in your Error Boundary's componentDidCatch
 *
 * @example
 * ```tsx
 * class ErrorBoundary extends React.Component {
 *   componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
 *     captureReactError(error, errorInfo);
 *   }
 * }
 * ```
 */
export function captureReactError(
  error: Error,
  errorInfo: { componentStack?: string }
): void {
  sendError({
    message: error.message,
    stack: error.stack,
    source: 'uncaught',
    componentStack: errorInfo.componentStack,
  });
}

// Auto-initialize if this script is loaded directly (not imported)
if (typeof window !== 'undefined' && !(window as any).__TELEMETRY_MANUAL_INIT__) {
  // Delay init to allow options to be set
  setTimeout(() => {
    if (!isInitialized) {
      initTelemetry();
    }
  }, 0);
}
