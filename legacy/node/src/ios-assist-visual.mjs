const PNG_HEADER_BYTES = 24;
const DEFAULT_PAUSE_CONFIDENCE = 0.9;
const DEFAULT_WARNING_CONFIDENCE = 0.75;

const SYSTEM_ALERT_TOKENS = [
  'XCUIElementTypeAlert',
  'Allow',
  'Don’t Allow',
  "Don't Allow",
  'OK',
  'Cancel',
  'Continue',
  'Not Now',
  'Trust',
  '允许',
  '不允许',
  '好',
  '取消',
  '继续',
  '稍后',
  '信任',
];

function decodePngDataUrl(dataUrl) {
  const match = /^data:image\/png;base64,([a-zA-Z0-9+/=]+)$/.exec(dataUrl ?? '');
  if (!match) {
    throw new Error('Screenshot payload is not a PNG data URL');
  }
  return Buffer.from(match[1], 'base64');
}

function parsePngInfo(dataUrl) {
  const bytes = decodePngDataUrl(dataUrl);
  if (bytes.length < PNG_HEADER_BYTES) {
    throw new Error('Screenshot PNG is too small to inspect');
  }
  const signature = bytes.subarray(0, 8).toString('hex');
  if (signature !== '89504e470d0a1a0a') {
    throw new Error('Screenshot payload is not a PNG image');
  }
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
    bytes: bytes.length,
  };
}

function sourceIncludes(source, token) {
  return source.toLowerCase().includes(token.toLowerCase());
}

function detectKnownSystemAlert(source) {
  if (!source) {
    return null;
  }
  const matchedTokens = SYSTEM_ALERT_TOKENS.filter((token) => sourceIncludes(source, token));
  const hasAlertType = matchedTokens.some((token) => token === 'XCUIElementTypeAlert');
  const hasAlertAction = matchedTokens.some((token) => token !== 'XCUIElementTypeAlert');
  if (!hasAlertType && matchedTokens.length < 2) {
    return null;
  }

  return {
    id: 'ios.system-alert',
    category: 'systemAlert',
    label: 'iOS system alert candidate',
    confidence: hasAlertType && hasAlertAction ? 0.95 : 0.82,
    matchedTokens,
    action: hasAlertType && hasAlertAction ? 'pause' : 'warn',
  };
}

function decisionFromChecks(checks, thresholds) {
  const pauseCheck = checks
    .filter((check) => check.action === 'pause')
    .sort((a, b) => b.confidence - a.confidence)[0];
  if (pauseCheck && pauseCheck.confidence >= thresholds.pauseConfidence) {
    return {
      action: 'pause',
      confidence: pauseCheck.confidence,
      reason: `${pauseCheck.label} requires manual confirmation`,
      ruleId: pauseCheck.id,
    };
  }

  const warningCheck = checks
    .filter((check) => check.action !== 'continue' && check.confidence >= thresholds.warningConfidence)
    .sort((a, b) => b.confidence - a.confidence)[0];
  if (warningCheck) {
    return {
      action: 'warn',
      confidence: warningCheck.confidence,
      reason: warningCheck.label,
      ruleId: warningCheck.id,
    };
  }

  return {
    action: 'continue',
    confidence: 1,
    reason: 'No blocking visual rule matched',
    ruleId: null,
  };
}

export function analyzeVisualSnapshot({
  screenshot,
  source = '',
  reason = 'manual',
  thresholds = {},
} = {}) {
  const resolvedThresholds = {
    pauseConfidence: thresholds.pauseConfidence ?? DEFAULT_PAUSE_CONFIDENCE,
    warningConfidence: thresholds.warningConfidence ?? DEFAULT_WARNING_CONFIDENCE,
  };
  const checks = [];
  const screenshotInfo = screenshot?.dataUrl
    ? parsePngInfo(screenshot.dataUrl)
    : null;

  if (screenshotInfo) {
    checks.push({
      id: 'screenshot.png-metadata',
      category: 'screenshot',
      label: 'Screenshot PNG metadata is readable',
      confidence: 1,
      action: 'continue',
      width: screenshotInfo.width,
      height: screenshotInfo.height,
      bytes: screenshotInfo.bytes,
    });
  }

  const alertCheck = detectKnownSystemAlert(source);
  if (alertCheck) {
    checks.push(alertCheck);
  }

  return {
    at: new Date().toISOString(),
    reason,
    capability: {
      screenshot: Boolean(screenshotInfo),
      pageSource: Boolean(source),
      ocr: false,
      cvModel: false,
    },
    screenshot: screenshotInfo,
    checks,
    decision: decisionFromChecks(checks, resolvedThresholds),
    thresholds: resolvedThresholds,
  };
}
