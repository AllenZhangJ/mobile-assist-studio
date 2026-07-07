const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const root = process.cwd();
const outDir = path.join(root, 'docs/prototypes/generated-images');
fs.mkdirSync(outDir, { recursive: true });

const palette = {
  paper: '#fbfaf7',
  ink: '#222222',
  muted: '#66645f',
  line: '#2f2f2f',
  grid: '#ece8dd',
  surface: '#ffffff',
  blue: '#0a84ff',
  green: '#248a3d',
  amber: '#b26a00',
  red: '#d70015',
  purple: '#6e56cf',
};

function esc(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function wrapText(text, max = 28) {
  const parts = String(text).split(/\s+/);
  if (parts.length > 1 && parts.every((part) => part.length < max)) {
    const lines = [];
    let current = '';
    for (const part of parts) {
      const next = current ? `${current} ${part}` : part;
      if (next.length > max) {
        lines.push(current);
        current = part;
      } else {
        current = next;
      }
    }
    if (current) lines.push(current);
    return lines;
  }
  const lines = [];
  let current = '';
  for (const char of String(text)) {
    const code = char.codePointAt(0);
    const width = code > 255 ? 2 : 1;
    const currentWidth = [...current].reduce(
      (sum, item) => sum + (item.codePointAt(0) > 255 ? 2 : 1),
      0,
    );
    if (currentWidth + width > max) {
      lines.push(current);
      current = char;
    } else {
      current += char;
    }
  }
  if (current) lines.push(current);
  return lines;
}

function textBlock(lines, x, y, options = {}) {
  const {
    size = 24,
    weight = 500,
    fill = palette.ink,
    lineHeight = Math.round(size * 1.45),
    max = 30,
    anchor = 'start',
  } = options;
  const normalized = Array.isArray(lines) ? lines : wrapText(lines, max);
  return `<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}">${normalized
    .map((line, index) => `<tspan x="${x}" dy="${index === 0 ? 0 : lineHeight}">${esc(line)}</tspan>`)
    .join('')}</text>`;
}

function markerDefs() {
  return `
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="${palette.line}" />
    </marker>
    <filter id="paperShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="3" stdDeviation="3" flood-color="#000000" flood-opacity="0.12"/>
    </filter>
  </defs>`;
}

function gridPattern(width, height) {
  const lines = [];
  for (let x = 0; x <= width; x += 48) {
    lines.push(`<line x1="${x}" y1="0" x2="${x}" y2="${height}" stroke="${palette.grid}" stroke-width="1"/>`);
  }
  for (let y = 0; y <= height; y += 48) {
    lines.push(`<line x1="0" y1="${y}" x2="${width}" y2="${y}" stroke="${palette.grid}" stroke-width="1"/>`);
  }
  return `<g opacity="0.55">${lines.join('')}</g>`;
}

function roughRect(x, y, w, h, options = {}) {
  const { fill = palette.surface, stroke = palette.line, strokeWidth = 3, rx = 18, dash = '' } = options;
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${stroke}" stroke-width="${strokeWidth}" ${dash ? `stroke-dasharray="${dash}"` : ''}/>
    <path d="M ${x + 5} ${y + h - 7} C ${x + w * 0.28} ${y + h - 1}, ${x + w * 0.73} ${y + h - 11}, ${x + w - 5} ${y + h - 5}" fill="none" stroke="${stroke}" stroke-opacity="0.18" stroke-width="2"/>
  `;
}

function arrow(x1, y1, x2, y2, label = '') {
  const midX = (x1 + x2) / 2;
  const midY = (y1 + y2) / 2 - 8;
  return `
    <line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${palette.line}" stroke-width="3" marker-end="url(#arrow)"/>
    ${label ? textBlock(label, midX, midY, { size: 16, fill: palette.muted, anchor: 'middle', max: 18 }) : ''}
  `;
}

function card(x, y, w, h, title, body) {
  return `
    <g>
      ${roughRect(x, y, w, h, { fill: palette.surface, strokeWidth: 3 })}
      ${textBlock(title, x + 28, y + 46, { size: 28, weight: 750, max: 32 })}
      ${body(x + 28, y + 82, w - 56, h - 110)}
    </g>
  `;
}

function miniFlow(items, x, y, w, colors = []) {
  const boxW = Math.min(190, Math.max(132, Math.floor((w - (items.length - 1) * 28) / items.length)));
  const gap = Math.max(18, Math.floor((w - boxW * items.length) / Math.max(1, items.length - 1)));
  let svg = '';
  items.forEach((item, index) => {
    const bx = x + index * (boxW + gap);
    const fill = colors[index] || '#f7f7fb';
    svg += roughRect(bx, y, boxW, 74, { fill, strokeWidth: 2, rx: 14 });
    svg += textBlock(item, bx + boxW / 2, y + 32, { size: 18, weight: 650, anchor: 'middle', max: 15 });
    if (index < items.length - 1) {
      svg += arrow(bx + boxW + 4, y + 37, bx + boxW + gap - 8, y + 37);
    }
  });
  return svg;
}

function bulletList(items, x, y, options = {}) {
  const { size = 19, gap = 31, max = 42 } = options;
  return items
    .map((item, index) => {
      const cy = y + index * gap;
      return `<circle cx="${x}" cy="${cy - 7}" r="5" fill="${palette.blue}"/>${textBlock(item, x + 18, cy, {
        size,
        fill: palette.ink,
        max,
      })}`;
    })
    .join('');
}

function simpleWireframe(x, y, w, h, labels) {
  const top = 42;
  const nav = 84;
  let svg = roughRect(x, y, w, h, { fill: '#fdfdfd', strokeWidth: 2, rx: 14 });
  svg += `<rect x="${x}" y="${y}" width="${w}" height="${top}" rx="14" fill="#f0f0f5" stroke="${palette.line}" stroke-width="2"/>`;
  svg += `<rect x="${x}" y="${y + top}" width="${nav}" height="${h - top}" fill="#f5f5f7" stroke="${palette.line}" stroke-width="2"/>`;
  svg += textBlock(labels.title, x + 20, y + 28, { size: 18, weight: 750, max: 22 });
  svg += textBlock(labels.nav || '任务导航', x + 12, y + top + 36, { size: 14, fill: palette.muted, max: 6 });
  const contentX = x + nav + 24;
  const contentY = y + top + 24;
  svg += roughRect(contentX, contentY, w - nav - 48, 76, { fill: '#ffffff', strokeWidth: 2, rx: 12 });
  svg += textBlock(labels.hero || labels.title, contentX + 18, contentY + 30, { size: 17, weight: 700, max: 28 });
  const rowY = contentY + 104;
  const colW = (w - nav - 72) / 2;
  svg += roughRect(contentX, rowY, colW, h - top - 150, { fill: '#ffffff', strokeWidth: 2, rx: 12 });
  svg += roughRect(contentX + colW + 24, rowY, colW, h - top - 150, { fill: '#ffffff', strokeWidth: 2, rx: 12 });
  svg += textBlock(labels.left || '主区域', contentX + 18, rowY + 34, { size: 15, max: 18 });
  svg += textBlock(labels.right || '详情区域', contentX + colW + 42, rowY + 34, { size: 15, max: 18 });
  return svg;
}

function sheet(title, subtitle, panels, fileBase, options = {}) {
  const width = options.width || 2400;
  const columns = options.columns || 2;
  const margin = 70;
  const gap = 36;
  const header = 190;
  const cardW = Math.floor((width - margin * 2 - gap * (columns - 1)) / columns);
  const rows = [];
  for (let i = 0; i < panels.length; i += columns) rows.push(panels.slice(i, i + columns));
  const rowHeights = rows.map((row) => Math.max(...row.map((panel) => panel.height || 360)));
  const height = header + rowHeights.reduce((sum, value) => sum + value, 0) + gap * (rows.length - 1) + margin;
  let y = header;
  let svg = `<?xml version="1.0" encoding="UTF-8"?>
  <svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    ${markerDefs()}
    <rect width="${width}" height="${height}" fill="${palette.paper}"/>
    ${gridPattern(width, height)}
    ${textBlock(title, margin, 86, { size: 48, weight: 800, max: 52 })}
    ${textBlock(subtitle, margin, 132, { size: 24, fill: palette.muted, max: 78 })}
    ${textBlock(`完整性: ${panels.length} 个面板`, width - margin, 86, { size: 22, fill: palette.muted, anchor: 'end', max: 24 })}
  `;
  rows.forEach((row, rowIndex) => {
    row.forEach((panel, colIndex) => {
      const x = margin + colIndex * (cardW + gap);
      const h = rowHeights[rowIndex];
      svg += card(x, y, cardW, h, panel.title, panel.render);
    });
    y += rowHeights[rowIndex] + gap;
  });
  svg += '</svg>';
  const svgPath = path.join(outDir, `${fileBase}.svg`);
  const pngPath = path.join(outDir, `${fileBase}.png`);
  fs.writeFileSync(svgPath, svg);
  return sharp(Buffer.from(svg)).png().toFile(pngPath).then(() => ({
    fileBase,
    title,
    svgPath,
    pngPath,
    width,
    height,
    expectedPanels: panels.length,
    actualPanels: panels.length,
    layoutComplete: y - gap <= height - margin + 1,
  }));
}

const flowPanels = [
  {
    title: '1. V2 到 V3 演进',
    height: 330,
    render: (x, y, w) =>
      miniFlow(['V2 iOS', '跨平台抽象', '资源锁', '目标库', 'Android', 'V3 工作站'], x, y + 22, w, [
        '#eef5ff',
        '#fff8e8',
        '#f4f0ff',
        '#eefaf0',
        '#fff0f0',
        '#eef5ff',
      ]) +
      bulletList(['保留单设备、串行执行、安全停止、Project DSL、本地证据', '新增 Target Resolver、Android MVP、结果归因'], x, y + 138, {
        max: 46,
      }),
  },
  {
    title: '2. 产品总流程',
    height: 360,
    render: (x, y, w) =>
      miniFlow(['打开', '连接', '创建目标', '录制', '编辑流程', '运行', '结果'], x, y + 22, w) +
      bulletList(['不能开始时给下一步', '低置信进入人工介入', '结果页跳回目标或流程修复'], x, y + 140, { max: 44 }),
  },
  {
    title: '3. 任务型 IA',
    height: 360,
    render: (x, y, w) =>
      miniFlow(['开始', '连接设备', '开始录制', '编辑流程', '运行任务', '查看结果'], x, y + 22, w) +
      bulletList(['Target Library 是共享面板，不升主导航', '设置和 Console 是辅助层', '命令面板提供全局跳转'], x, y + 140, { max: 44 }),
  },
  {
    title: '4. 跨平台 Runtime',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['Flutter UI', 'Runtime', 'Mobile Driver', 'iOS/Android', 'Evidence'], x, y + 22, w) +
      bulletList(['UI 不直接调用 adapter', 'Runtime 拥有锁、目标、执行、证据', 'OCR/CV 只辅助解析，不直接点击'], x, y + 140, { max: 46 }),
  },
  {
    title: '5. 资源锁状态机',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['idle', 'remote', 'recording', 'running', 'paused', 'stopping'], x, y + 22, w, [
        '#eefaf0',
        '#eef5ff',
        '#fff8e8',
        '#eef5ff',
        '#f4f0ff',
        '#fff0f0',
      ]) +
      bulletList(['远控和自动化动作不能并发', '运行中不能写 workflow 或 target', 'paused 是人工介入态，不是失败态'], x, y + 140, { max: 46 }),
  },
  {
    title: '6. Target Library 数据流',
    height: 360,
    render: (x, y, w) =>
      miniFlow(['当前画面', '目标草稿', 'Inspector', 'Target Store', '流程引用'], x, y + 22, w) +
      bulletList(['保存前校验平台能力', '缺失引用进入检查视图', '删除目标保护引用节点'], x, y + 140, { max: 44 }),
  },
  {
    title: '7. Target Resolver 决策',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['目标定义', 'Selector', 'Image/Region', 'OCR', 'Coordinate', '暂停/失败'], x, y + 22, w) +
      bulletList(['优先稳定策略', '坐标只作显式兜底', '低置信不点击，写入证据'], x, y + 140, { max: 44 }),
  },
  {
    title: '8. Workflow 执行',
    height: 360,
    render: (x, y, w) =>
      miniFlow(['预检', '确认', '获取锁', '执行节点', '写证据', '释放锁'], x, y + 22, w) +
      bulletList(['目标动作先解析再执行', '断言写 Test Result', '安全停止等待原子动作结算'], x, y + 140, { max: 44 }),
  },
  {
    title: '9. 结果三层模型',
    height: 360,
    render: (x, y, w) =>
      miniFlow(['Run Status', 'Test Result', 'Issue Category'], x + 80, y + 30, w - 160, [
        '#eef5ff',
        '#eefaf0',
        '#fff8e8',
      ]) +
      bulletList(['设备断线不等于断言失败', '手动停止是 stopped', '低置信通常是 paused / inconclusive'], x, y + 140, {
        max: 44,
      }),
  },
  {
    title: '10. Monitor 证据读取',
    height: 360,
    render: (x, y, w) =>
      miniFlow(['运行历史', 'Run Detail', '路径', '目标链', '日志/性能', '建议'], x, y + 22, w) +
      bulletList(['只读本地 evidence', '修复目标或流程可跳转', '复制摘要必须脱敏'], x, y + 140, { max: 44 }),
  },
];

const sequencePanels = [
  {
    title: '1. 连接当前设备',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['用户', 'Flutter UI', 'Runtime', 'Driver', 'Adapter', '设备', 'Snapshot'], x, y + 22, w) +
      bulletList(['点击连接设备', '自动识别 iOS 或 Android', '写入脱敏设备摘要和截图'], x, y + 140, { max: 44 }),
  },
  {
    title: '2. 从预览创建目标',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['用户', '预览', '草稿', 'Inspector', 'Validator', 'Target Store'], x, y + 22, w) +
      bulletList(['请求 targetCapture 资源锁', '点选或框选画面', '保存前校验平台能力'], x, y + 140, { max: 44 }),
  },
  {
    title: '3. 录制并生成流程',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['用户', 'Recorder', 'Timeline', 'Runtime', 'DSL', 'Store'], x, y + 22, w) +
      bulletList(['动作以 Target + Action 展示', '生成 Project DSL', 'validator 通过后保存当前流程'], x, y + 140, {
        max: 44,
      }),
  },
  {
    title: '4. 执行 Tap Target',
    height: 400,
    render: (x, y, w) =>
      miniFlow(['Execute', 'Runtime', 'Runner', 'Resolver', 'Driver', 'Device', 'Evidence'], x, y + 22, w) +
      bulletList(['预检通过后确认运行', '解析目标后才点击', '写入目标解析和动作事件'], x, y + 150, { max: 46 }),
  },
  {
    title: '5. 低置信暂停介入',
    height: 400,
    render: (x, y, w) =>
      miniFlow(['Resolver', 'Runtime', 'Execute', '用户', 'Device', 'Inspector', '收口'], x, y + 22, w) +
      bulletList(['低置信不盲点', '用户查看现场并更新目标', 'resolvePause 回到可操作状态'], x, y + 150, { max: 46 }),
  },
  {
    title: '6. Monitor 查看详情',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['用户', 'Monitor', 'Evidence API', 'Store', 'Run Detail', '修复入口'], x, y + 22, w) +
      bulletList(['读取本地证据', '分开展示任务状态、用例结果和问题类型', '可跳回目标或流程'], x, y + 140, {
        max: 46,
      }),
  },
  {
    title: '7. 日志和性能采样',
    height: 380,
    render: (x, y, w) =>
      miniFlow(['Runner', 'Driver', 'iOS/Android', 'Evidence', 'Monitor'], x, y + 22, w) +
      bulletList(['iOS 读取 syslog 摘要', 'Android 读取 logcat / dumpsys 摘要', '长期保存前裁剪脱敏'], x, y + 140, {
        max: 46,
      }),
  },
];

const pagePanels = [
  ['Global Shell', '当前状态、当前位置和下一步', '任务导航', '工作区 / Drawer'],
  ['开始', 'Next Best Action', '最近流程', '最近问题'],
  ['连接设备', '当前设备摘要', '设备画面预览', '创建目标'],
  ['Target Inspector', '名称和策略', '测试识别', '保存目标'],
  ['开始录制', '设备预览', '动作时间轴', '生成流程'],
  ['编辑流程', '目标库 / 节点', '画布', 'Inspector'],
  ['Source / Validate', 'DSL 编辑', '诊断定位', '保存源码'],
  ['运行任务', '预检', '当前运行', '安全停止'],
  ['暂停介入', '低置信原因', '现场画面', '更新目标'],
  ['查看结果', '结果 KPI', '运行历史', '详情入口'],
  ['Run Detail', '状态 / 结果 / 问题', '目标解析链', '复制摘要'],
  ['Settings', '本地设置', '隐私边界', '证据保留'],
  ['Bottom Console', 'Log / Error / Driver', 'Targets / Performance', '复制/清除视图'],
  ['Command Center', '搜索命令', '跳转页面', '安全命令'],
].map(([title, hero, left, right]) => ({
  title,
  height: 420,
  render: (x, y, w, h) => simpleWireframe(x, y + 14, w, h - 26, { title, hero, left, right }),
}));

const htmlPanels = [
  ['开始', '登录检查可以运行', '三段摘要', '最近流程 / 问题'],
  ['连接设备', 'iOS 已连接', '设备画面', '创建目标'],
  ['开始录制', '现场预览', '动作时间轴', '生成流程'],
  ['编辑流程', '目标库', '流程画布', 'Inspector'],
  ['运行任务', '等待人工确认', '预检', '当前运行'],
  ['查看结果', '结果指标', '运行历史', '详情'],
  ['目标 Drawer', '登录按钮', '策略和验证', '保存目标'],
  ['运行详情 Drawer', '三层结果', '目标解析链', '复制摘要'],
  ['命令 + Console', '⌘K 搜索', '底部诊断', '脱敏摘要'],
].map(([title, hero, left, right]) => ({
  title,
  height: 430,
  render: (x, y, w, h) => simpleWireframe(x, y + 14, w, h - 26, { title, hero, left, right }),
}));

async function imageStats(pngPath) {
  const image = sharp(pngPath);
  const meta = await image.metadata();
  const { data, info } = await image.raw().toBuffer({ resolveWithObject: true });
  let inkPixels = 0;
  for (let index = 0; index < data.length; index += info.channels) {
    const r = data[index];
    const g = data[index + 1];
    const b = data[index + 2];
    const distance = Math.abs(r - 251) + Math.abs(g - 250) + Math.abs(b - 247);
    if (distance > 28) inkPixels += 1;
  }
  const pixels = info.width * info.height;
  const nonBackgroundRatio = Number((inkPixels / pixels).toFixed(4));
  return {
    width: meta.width,
    height: meta.height,
    sizeBytes: fs.statSync(pngPath).size,
    nonBackgroundRatio,
    nonBlank: nonBackgroundRatio > 0.015,
  };
}

function countNumberedHeadings(file) {
  const markdown = fs.readFileSync(path.join(root, file), 'utf8');
  const matches = markdown.match(/^##\s+\d+\./gm);
  return matches ? matches.length : 0;
}

async function main() {
  const results = [];
  results.push(
    await sheet(
      'V3.0 流程图专项图片',
      '覆盖 V2 到 V3、产品总流程、任务 IA、Runtime、资源锁、Target、执行、结果和 Monitor。',
      flowPanels,
      'v3-flowcharts-specialized',
    ),
  );
  results.push(
    await sheet(
      'V3.0 时序图专项图片',
      '覆盖连接设备、创建目标、录制生成、Tap Target、低置信暂停、结果查看、日志性能采样。',
      sequencePanels,
      'v3-sequence-diagrams-specialized',
    ),
  );
  results.push(
    await sheet(
      'V3.0 页面原型专项图片',
      '覆盖全局壳、六个任务页、Target / Run / Settings / Console / Command Center。',
      pagePanels,
      'v3-page-prototypes-specialized',
    ),
  );
  results.push(
    await sheet(
      'V3.0 HTML 静态原型图片',
      '将离线 HTML 原型的主要页面和浮层整理为完整总览截图式图片。',
      htmlPanels,
      'v3-html-static-prototype-overview',
    ),
  );

  const sourceCounts = {
    flowcharts: countNumberedHeadings('docs/V3.0-Flowcharts-Specialized.md'),
    sequences: countNumberedHeadings('docs/V3.0-Sequence-Diagrams-Specialized.md'),
    pagePrototypes: countNumberedHeadings('docs/V3.0-Page-Prototypes-Specialized.md'),
    htmlPrototypePanels: htmlPanels.length,
  };

  const expected = {
    'v3-flowcharts-specialized': sourceCounts.flowcharts,
    'v3-sequence-diagrams-specialized': sourceCounts.sequences,
    'v3-page-prototypes-specialized': sourceCounts.pagePrototypes,
    'v3-html-static-prototype-overview': sourceCounts.htmlPrototypePanels,
  };

  const verified = [];
  for (const result of results) {
    const stats = await imageStats(result.pngPath);
    const expectedPanels = expected[result.fileBase];
    const panelCountMatches = result.actualPanels === expectedPanels;
    const complete =
      result.layoutComplete &&
      panelCountMatches &&
      stats.nonBlank &&
      stats.width === result.width &&
      stats.height === result.height &&
      stats.sizeBytes > 50000;
    verified.push({
      name: result.fileBase,
      png: path.relative(root, result.pngPath),
      svg: path.relative(root, result.svgPath),
      expectedPanels,
      actualPanels: result.actualPanels,
      panelCountMatches,
      layoutComplete: result.layoutComplete,
      ...stats,
      complete,
    });
  }

  const report = {
    generatedAt: new Date().toISOString(),
    sourceCounts,
    images: verified,
    allComplete: verified.every((item) => item.complete),
  };
  const reportPath = path.join(outDir, 'v3-specialized-image-verification.json');
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

  const markdown = [
    '# V3.0 Specialized Image Verification',
    '',
    `Generated at: ${report.generatedAt}`,
    '',
    '| Image | Expected | Actual | Size | Non-bg | Complete |',
    '|---|---:|---:|---:|---:|---|',
    ...verified.map((item) =>
      `| ${item.png} | ${item.expectedPanels} | ${item.actualPanels} | ${item.width}x${item.height} | ${item.nonBackgroundRatio} | ${item.complete ? 'yes' : 'no'} |`,
    ),
    '',
    `All complete: ${report.allComplete ? 'yes' : 'no'}`,
    '',
  ].join('\n');
  fs.writeFileSync(path.join(outDir, 'v3-specialized-image-verification.md'), markdown);
  console.log(markdown);

  if (!report.allComplete) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
