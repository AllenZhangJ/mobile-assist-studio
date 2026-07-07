export function publicText(value) {
  return String(value ?? '')
    .replace(/\/(?:Users|private|tmp|var|Volumes)(?:\/[^\s'")]+)?/g, '[path]')
    .replace(/\b[0-9A-Fa-f]{8,}-[0-9A-Fa-f-]{12,}\b/g, '[device-id]')
    .replace(/\b[0-9A-Fa-f]{24,40}\b/g, '[device-id]');
}

export function publicErrorMessage(error) {
  return publicText(error?.message ?? error ?? 'request failed');
}
