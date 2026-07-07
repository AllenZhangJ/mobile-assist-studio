import { publicText } from './ios-assist-public-text.mjs';

export function publicPayload(value) {
  if (typeof value === 'string') {
    return publicText(value);
  }
  if (!value || typeof value !== 'object') {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map(publicPayload);
  }

  const copy = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === 'dataUrl') {
      continue;
    }
    copy[key] = publicPayload(child);
  }
  return copy;
}
