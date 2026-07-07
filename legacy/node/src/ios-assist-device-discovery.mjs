import { withTimeout } from './ios-assist-session.mjs';

export function createDeviceDiscoveryStatus({
  discoverDevices,
  timeoutMs = 1500,
  retryCooldownMs = 5000,
  timeoutMessage = 'USB device discovery timed out',
  sanitizeError = (error) => String(error?.message ?? error),
} = {}) {
  const state = {
    inFlight: null,
    acceptToken: null,
    cooldownUntil: 0,
    lastDevices: [],
    lastError: null,
  };

  const startProbe = () => {
    const token = {};
    state.acceptToken = token;
    const probe = Promise.resolve()
      .then(discoverDevices)
      .then((devices) => {
        if (state.acceptToken === token) {
          state.lastDevices = Array.isArray(devices) ? devices : [];
          state.lastError = null;
        }
        return {
          devices: state.lastDevices,
          error: null,
          stale: false,
        };
      })
      .catch((error) => {
        if (state.acceptToken === token) {
          state.lastError = sanitizeError(error);
        }
        return {
          devices: state.lastDevices,
          error: state.lastError,
          stale: true,
        };
      })
      .finally(() => {
        if (state.inFlight === probe) {
          state.inFlight = null;
          state.acceptToken = null;
        }
      });
    state.inFlight = probe;
    return probe;
  };

  return async function discoverForStatus() {
    const now = Date.now();
    if (!state.inFlight && now < state.cooldownUntil) {
      return {
        devices: state.lastDevices,
        error: state.lastError ?? timeoutMessage,
        stale: true,
      };
    }

    const probe = state.inFlight ?? startProbe();
    try {
      return await withTimeout(probe, timeoutMs, timeoutMessage);
    } catch (error) {
      const message = sanitizeError(error);
      state.lastError = message;
      if (state.inFlight === probe) {
        state.inFlight = null;
        state.acceptToken = null;
        state.cooldownUntil = Date.now() + retryCooldownMs;
      }
      return {
        devices: state.lastDevices,
        error: message,
        stale: true,
      };
    }
  };
}
