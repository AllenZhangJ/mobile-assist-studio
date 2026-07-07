part of '../studio_runtime.dart';

const _defaultPythonPackages = ['airtest', 'pyxelator'];
const _defaultOcrEvidenceRef = 'vision://python-ocr';

// PythonSidecarStatus 表示 Python 视觉能力准备状态。
// 缺失 Python 或包时，不应阻断坐标和 Appium 基础流程。
enum PythonSidecarStatus { unknown, ready, partial, unavailable }

// PythonSidecarRunResult 表示一次短生命周期 Python 调用结果。
// stdout / stderr 会被调用方解析或裁剪，不直接进入 UI。
final class PythonSidecarRunResult {
  // 创建 Python 调用结果。
  const PythonSidecarRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

typedef PythonVisionSidecarRunner =
    Future<PythonSidecarRunResult> Function(
      String executable,
      String script,
      String inputJson,
      Duration timeout,
    );

// PythonVisionBackend 表示 Python 视觉调用的目标后端。
// auto 由 Python 脚本选择，builtin 只使用内置 PNG 匹配兜底。
enum PythonVisionBackend { auto, pyxelator, airtest, builtin }

// PythonSidecarReport 是 Python sidecar 的脱敏能力报告。
// 它只记录包可用性，不保存本机路径或命令原始输出。
final class PythonSidecarReport {
  // 创建 Python sidecar 报告。
  const PythonSidecarReport({
    required this.status,
    required this.executableLabel,
    required this.packages,
    required this.message,
  });

  final PythonSidecarStatus status;
  final String executableLabel;
  final Map<String, bool> packages;
  final String message;

  // 判断指定 Python 包是否可用。
  bool supportsPackage(String packageName) => packages[packageName] ?? false;

  static const unknown = PythonSidecarReport(
    status: PythonSidecarStatus.unknown,
    executableLabel: 'python',
    packages: <String, bool>{},
    message: '尚未检查 Python 视觉能力。',
  );
}

// PythonSidecarProbe 负责探测 Airtest / Pyxelator 等 Python 包。
// 它只做能力检查，不启动长期进程，也不直接控制设备。
final class PythonSidecarProbe {
  // 创建 Python sidecar 探测器，可注入命令执行器以便测试。
  const PythonSidecarProbe({
    CommandRunner runner = defaultCommandRunner,
    this.timeout = const Duration(seconds: 4),
  }) : _runner = runner;

  final CommandRunner _runner;
  final Duration timeout;

  // 检查 Python 可执行文件和指定包是否可用。
  Future<PythonSidecarReport> check({
    String executable = 'python3',
    List<String> packages = _defaultPythonPackages,
  }) async {
    try {
      final result = await _runner(executable, [
        '-c',
        _packageProbeScript(packages),
      ]).timeout(timeout);
      if (result.exitCode != 0) {
        return _unavailable(executable);
      }
      final packageMap = _parsePackageProbe('${result.stdout}');
      final availableCount = packageMap.values.where((value) => value).length;
      if (availableCount == packages.length) {
        return PythonSidecarReport(
          status: PythonSidecarStatus.ready,
          executableLabel: _executableLabel(executable),
          packages: Map<String, bool>.unmodifiable(packageMap),
          message: 'Python 视觉能力可用。',
        );
      }
      if (availableCount > 0) {
        return PythonSidecarReport(
          status: PythonSidecarStatus.partial,
          executableLabel: _executableLabel(executable),
          packages: Map<String, bool>.unmodifiable(packageMap),
          message: '部分 Python 视觉能力可用。',
        );
      }
      return PythonSidecarReport(
        status: PythonSidecarStatus.unavailable,
        executableLabel: _executableLabel(executable),
        packages: Map<String, bool>.unmodifiable(packageMap),
        message: '未发现可用的 Python 视觉包。',
      );
    } on Object {
      return _unavailable(executable);
    }
  }

  // 生成 Python 包探测脚本，输出稳定的 package=0/1 行。
  String _packageProbeScript(List<String> packages) {
    final packageList = packages.map((package) => "'$package'").join(',');
    return [
      'import importlib.util',
      'packages=[$packageList]',
      'for name in packages:',
      ' print(f"{name}={1 if importlib.util.find_spec(name) else 0}")',
    ].join('\n');
  }

  // 解析 Python 探测输出为包名到可用性的映射。
  Map<String, bool> _parsePackageProbe(String output) {
    final result = <String, bool>{};
    for (final line in output.split(RegExp(r'\r?\n'))) {
      final parts = line.trim().split('=');
      if (parts.length != 2 || parts.first.isEmpty) continue;
      result[parts.first] = parts.last == '1';
    }
    return result;
  }

  // 创建不可用报告，并隐藏完整可执行文件路径。
  PythonSidecarReport _unavailable(String executable) {
    return PythonSidecarReport(
      status: PythonSidecarStatus.unavailable,
      executableLabel: _executableLabel(executable),
      packages: const <String, bool>{},
      message: 'Python 视觉能力不可用。',
    );
  }

  // 只保留可执行文件名称，避免绝对路径进入 UI。
  String _executableLabel(String executable) {
    return executable.split(RegExp(r'[/\\]')).last;
  }
}

// PythonVisionSidecarClient 负责调用短生命周期 Python 视觉脚本。
// 它只通过 stdin/stdout 交换 JSON，不持有设备动作能力。
final class PythonVisionSidecarClient {
  // 创建 Python 视觉 sidecar 客户端。
  const PythonVisionSidecarClient({
    PythonVisionSidecarRunner runner = defaultPythonVisionSidecarRunner,
    this.executable = 'python3',
    this.timeout = const Duration(seconds: 6),
  }) : _runner = runner;

  final PythonVisionSidecarRunner _runner;
  final String executable;
  final Duration timeout;

  // 请求 Python sidecar 定位图片模板。
  Future<Map<String, Object?>> locateTemplate({
    required String screenshotBase64,
    required String templateBase64,
    required double confidenceThreshold,
    PythonVisionBackend backend = PythonVisionBackend.auto,
  }) async {
    final input = jsonEncode(<String, Object?>{
      'screenshotBase64': screenshotBase64,
      'templateBase64': templateBase64,
      'confidenceThreshold': confidenceThreshold,
      'backend': backend.name,
    });
    final result = await _runner(
      executable,
      _pythonTemplateLocatorScript,
      input,
      timeout,
    );
    if (result.exitCode != 0) {
      return <String, Object?>{
        'status': 'infrastructureError',
        'message': _shortPythonSidecarError(result.stderr),
      };
    }
    try {
      final decoded = jsonDecode(result.stdout);
      if (decoded is Map<String, Object?>) return decoded;
    } on Object {
      return <String, Object?>{
        'status': 'infrastructureError',
        'message': 'Python 视觉结果不可读。',
      };
    }
    return <String, Object?>{
      'status': 'infrastructureError',
      'message': 'Python 视觉结果格式不正确。',
    };
  }

  // 请求 Python sidecar 使用 OCR 定位文本目标。
  Future<Map<String, Object?>> locateText({
    required String screenshotBase64,
    required String query,
    required double confidenceThreshold,
  }) async {
    final input = jsonEncode(<String, Object?>{
      'screenshotBase64': screenshotBase64,
      'query': query,
      'confidenceThreshold': confidenceThreshold,
    });
    final result = await _runner(
      executable,
      _pythonOcrLocatorScript,
      input,
      timeout,
    );
    if (result.exitCode != 0) {
      return <String, Object?>{
        'status': 'infrastructureError',
        'message': _shortPythonSidecarError(result.stderr),
        'evidenceRef': _defaultOcrEvidenceRef,
      };
    }
    try {
      final decoded = jsonDecode(result.stdout);
      if (decoded is Map<String, Object?>) return decoded;
    } on Object {
      return <String, Object?>{
        'status': 'infrastructureError',
        'message': 'Python OCR 结果不可读。',
        'evidenceRef': _defaultOcrEvidenceRef,
      };
    }
    return <String, Object?>{
      'status': 'infrastructureError',
      'message': 'Python OCR 结果格式不正确。',
      'evidenceRef': _defaultOcrEvidenceRef,
    };
  }
}

// 默认 Python sidecar runner，通过 stdin 传入 JSON 并读取 stdout。
Future<PythonSidecarRunResult> defaultPythonVisionSidecarRunner(
  String executable,
  String script,
  String inputJson,
  Duration timeout,
) async {
  final process = await Process.start(executable, ['-c', script]);
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  process.stdin.write(inputJson);
  await process.stdin.close();
  late final int exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill();
    return const PythonSidecarRunResult(
      exitCode: 124,
      stdout: '',
      stderr: 'timeout',
    );
  }
  return PythonSidecarRunResult(
    exitCode: exitCode,
    stdout: await stdoutFuture,
    stderr: await stderrFuture,
  );
}

// 裁剪 Python 错误，避免长栈或路径进入 UI。
String _shortPythonSidecarError(String stderr) {
  final firstLine = stderr.split(RegExp(r'\r?\n')).first.trim();
  if (firstLine.isEmpty || firstLine == 'timeout') {
    return 'Python 视觉能力不可用。';
  }
  final sanitized = firstLine
      .replaceAll(RegExp(r'/Users/[^ ]+'), '[path]')
      .replaceAll(RegExp(r'file://[^ ]+'), '[path]');
  return sanitized.length > 120 ? sanitized.substring(0, 120) : sanitized;
}

const _pythonTemplateLocatorScript = r'''
import base64
import importlib.util
import json
import os
import struct
import sys
import tempfile
import zlib


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False))
    sys.exit(0)


def fail(status, message, evidence_ref=None):
    payload = {"status": status, "message": message}
    if evidence_ref:
        payload["evidenceRef"] = evidence_ref
    emit(payload)


def package_available(name):
    return importlib.util.find_spec(name) is not None


def status_payload(status, message, evidence_ref, x=0, y=0, width=0, height=0, confidence=0):
    return {
        "status": status,
        "message": message,
        "x": x,
        "y": y,
        "centerX": int(x + width / 2 + 0.5),
        "centerY": int(y + height / 2 + 0.5),
        "width": width,
        "height": height,
        "confidence": confidence,
        "evidenceRef": evidence_ref,
    }


def normalize_match(raw, evidence_ref, threshold):
    if not raw:
        return {"status": "notMatched", "message": "未找到目标。", "confidence": 0, "evidenceRef": evidence_ref}
    if isinstance(raw, (list, tuple)) and raw and isinstance(raw[0], dict):
        raw = raw[0]
    if not isinstance(raw, dict):
        return {"status": "unsupported", "message": "视觉包返回格式暂不支持。", "evidenceRef": evidence_ref}

    confidence = raw.get("confidence", raw.get("score", raw.get("similarity", 1)))
    try:
        confidence = float(confidence)
    except Exception:
        confidence = 1

    center = raw.get("result") or raw.get("center") or raw.get("point")
    x = raw.get("x")
    y = raw.get("y")
    width = raw.get("width", raw.get("w", 0))
    height = raw.get("height", raw.get("h", 0))
    rectangle = raw.get("rectangle") or raw.get("rect")
    if center and isinstance(center, (list, tuple)) and len(center) >= 2:
        try:
            cx, cy = float(center[0]), float(center[1])
            if width and height:
                x = cx - float(width) / 2
                y = cy - float(height) / 2
            else:
                x = cx
                y = cy
        except Exception:
            pass
    if rectangle and isinstance(rectangle, (list, tuple)) and len(rectangle) >= 2:
        try:
            xs = [float(point[0]) for point in rectangle]
            ys = [float(point[1]) for point in rectangle]
            x = min(xs)
            y = min(ys)
            width = max(xs) - min(xs)
            height = max(ys) - min(ys)
        except Exception:
            pass

    try:
        x = float(x)
        y = float(y)
        width = float(width)
        height = float(height)
    except Exception:
        return {"status": "unsupported", "message": "视觉包缺少目标范围。", "evidenceRef": evidence_ref}

    status = "matched" if confidence >= threshold else "notMatched" if confidence <= 0 else "lowConfidence"
    message = "已找到目标。" if status == "matched" else "未找到目标。" if status == "notMatched" else "目标置信度不足。"
    return status_payload(status, message, evidence_ref, x=x, y=y, width=width, height=height, confidence=confidence)


def with_temp_pngs(screen_bytes, template_bytes, callback):
    screen_path = template_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as screen_file:
            screen_file.write(screen_bytes)
            screen_path = screen_file.name
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as template_file:
            template_file.write(template_bytes)
            template_path = template_file.name
        return callback(screen_path, template_path)
    finally:
        for path in (screen_path, template_path):
            if path:
                try:
                    os.unlink(path)
                except Exception:
                    pass


def locate_with_airtest(screen_bytes, template_bytes, threshold):
    if not package_available("airtest"):
        fail("unsupported", "Airtest 视觉包不可用。", "vision://airtest-sidecar")
    try:
        from airtest import aircv

        def run(screen_path, template_path):
            screen = aircv.imread(screen_path)
            template = aircv.imread(template_path)
            return aircv.find_template(screen, template, threshold=threshold)

        raw = with_temp_pngs(screen_bytes, template_bytes, run)
        emit(normalize_match(raw, "vision://airtest-sidecar", threshold))
    except SystemExit:
        raise
    except Exception:
        fail("unsupported", "Airtest 视觉 API 暂不可用。", "vision://airtest-sidecar")


def locate_with_pyxelator(screen_bytes, template_bytes, threshold):
    if not package_available("pyxelator"):
        fail("unsupported", "Pyxelator 视觉包不可用。", "vision://pyxelator-sidecar")
    try:
        import pyxelator

        candidate_names = (
            "locate_template",
            "find_template",
            "locate",
            "find",
            "match_template",
        )

        def run(screen_path, template_path):
            for name in candidate_names:
                fn = getattr(pyxelator, name, None)
                if not callable(fn):
                    continue
                for args in ((screen_path, template_path), (template_path, screen_path)):
                    try:
                        return fn(*args, threshold=threshold)
                    except TypeError:
                        try:
                            return fn(*args)
                        except Exception:
                            continue
                    except Exception:
                        continue
            return {"status": "unsupported", "message": "Pyxelator 视觉 API 暂不支持。"}

        raw = with_temp_pngs(screen_bytes, template_bytes, run)
        if isinstance(raw, dict) and raw.get("status") == "unsupported":
            fail("unsupported", raw.get("message", "Pyxelator 视觉 API 暂不支持。"), "vision://pyxelator-sidecar")
        emit(normalize_match(raw, "vision://pyxelator-sidecar", threshold))
    except SystemExit:
        raise
    except Exception:
        fail("unsupported", "Pyxelator 视觉 API 暂不可用。", "vision://pyxelator-sidecar")


def locate_with_builtin(screen, template, threshold):
    if template["width"] > screen["width"] or template["height"] > screen["height"]:
        fail("notMatched", "未找到目标。", "vision://python-builtin")

    positions = (screen["width"] - template["width"] + 1) * (screen["height"] - template["height"] + 1)
    if positions * template["width"] * template["height"] > 25000000:
        fail("unsupported", "图片过大，请缩小模板或使用专用视觉服务。", "vision://python-builtin")

    best = None
    for y in range(screen["height"] - template["height"] + 1):
        for x in range(screen["width"] - template["width"] + 1):
            score = diff_at(screen, template, x, y)
            if best is None or score < best[0]:
                best = (score, x, y)
            if score == 0:
                break
        if best is not None and best[0] == 0:
            break

    max_diff = template["width"] * template["height"] * 3 * 255
    confidence = 0 if max_diff <= 0 else max(0, min(1, 1 - best[0] / max_diff))
    status = "matched" if confidence >= threshold else "notMatched" if confidence <= 0 else "lowConfidence"
    message = "已找到目标。" if status == "matched" else "未找到目标。" if status == "notMatched" else "目标置信度不足。"
    emit(status_payload(
        status,
        message,
        "vision://python-builtin",
        x=best[1],
        y=best[2],
        width=template["width"],
        height=template["height"],
        confidence=confidence,
    ))


def fail_if_invalid_backend(backend):
    if backend not in ("auto", "pyxelator", "airtest", "builtin"):
        fail("unsupported", "未知 Python 视觉后端。")


def dispatch_backend(backend, screen_bytes, template_bytes, screen, template, threshold):
    fail_if_invalid_backend(backend)
    if backend == "pyxelator":
        locate_with_pyxelator(screen_bytes, template_bytes, threshold)
    if backend == "airtest":
        locate_with_airtest(screen_bytes, template_bytes, threshold)
    if backend == "builtin":
        locate_with_builtin(screen, template, threshold)
    if package_available("pyxelator"):
        locate_with_pyxelator(screen_bytes, template_bytes, threshold)
    if package_available("airtest"):
        locate_with_airtest(screen_bytes, template_bytes, threshold)
    locate_with_builtin(screen, template, threshold)


def read_png(data):
    signature = b"\x89PNG\r\n\x1a\n"
    if len(data) < 33 or data[:8] != signature:
        return None
    offset = 8
    width = height = bit_depth = color_type = 0
    chunks = []
    while offset + 8 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        offset += 4
        chunk_type = data[offset:offset + 4]
        offset += 4
        chunk_data = data[offset:offset + length]
        offset += length + 4
        if chunk_type == b"IHDR":
            width, height = struct.unpack(">II", chunk_data[:8])
            bit_depth = chunk_data[8]
            color_type = chunk_data[9]
        elif chunk_type == b"IDAT":
            chunks.append(chunk_data)
        elif chunk_type == b"IEND":
            break
    if width <= 0 or height <= 0 or bit_depth != 8:
        return None
    channels = {0: 1, 2: 3, 6: 4}.get(color_type)
    if channels is None:
        return None
    inflated = zlib.decompress(b"".join(chunks))
    row_bytes = width * channels
    if len(inflated) < (row_bytes + 1) * height:
        return None
    raw = bytearray(row_bytes * height)
    source = 0
    for y in range(height):
        filter_type = inflated[source]
        source += 1
        row_start = y * row_bytes
        for x in range(row_bytes):
            current = inflated[source + x]
            left = raw[row_start + x - channels] if x >= channels else 0
            up = raw[row_start + x - row_bytes] if y > 0 else 0
            up_left = raw[row_start + x - row_bytes - channels] if y > 0 and x >= channels else 0
            if filter_type == 0:
                value = current
            elif filter_type == 1:
                value = (current + left) & 255
            elif filter_type == 2:
                value = (current + up) & 255
            elif filter_type == 3:
                value = (current + ((left + up) // 2)) & 255
            else:
                estimate = left + up - up_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - up_left))
                value = (current + (left if distances[0] <= distances[1] and distances[0] <= distances[2] else up if distances[1] <= distances[2] else up_left)) & 255
            raw[row_start + x] = value
        source += row_bytes
    rgb = bytearray(width * height * 3)
    for y in range(height):
        for x in range(width):
            raw_offset = y * row_bytes + x * channels
            rgb_offset = (y * width + x) * 3
            if channels == 1:
                rgb[rgb_offset:rgb_offset + 3] = bytes([raw[raw_offset]]) * 3
            else:
                rgb[rgb_offset:rgb_offset + 3] = raw[raw_offset:raw_offset + 3]
    return {"width": width, "height": height, "rgb": rgb}


def offset(image, x, y):
    return (y * image["width"] + x) * 3


def diff_at(screen, template, ox, oy):
    total = 0
    for y in range(template["height"]):
        for x in range(template["width"]):
            so = offset(screen, ox + x, oy + y)
            to = offset(template, x, y)
            total += abs(screen["rgb"][so] - template["rgb"][to])
            total += abs(screen["rgb"][so + 1] - template["rgb"][to + 1])
            total += abs(screen["rgb"][so + 2] - template["rgb"][to + 2])
    return total


try:
    request = json.loads(sys.stdin.read())
    threshold = float(request.get("confidenceThreshold", 0.8))
    backend = str(request.get("backend", "auto"))
    screen_bytes = base64.b64decode(request["screenshotBase64"])
    template_bytes = base64.b64decode(request["templateBase64"])
    screen = read_png(screen_bytes)
    template = read_png(template_bytes)
except Exception:
    fail("infrastructureError", "Python 视觉输入不可读。")

if screen is None or template is None:
    fail("infrastructureError", "Python 视觉图片不可读。")

dispatch_backend(backend, screen_bytes, template_bytes, screen, template, threshold)
''';

const _pythonOcrLocatorScript = r'''
import base64
import importlib.util
import json
import os
import sys
import tempfile


EVIDENCE_REF = "vision://python-ocr"


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False))
    sys.exit(0)


def fail(status, message):
    emit({"status": status, "message": message, "evidenceRef": EVIDENCE_REF})


def package_available(name):
    return importlib.util.find_spec(name) is not None


def normalize_text(value):
    return " ".join(str(value or "").split()).strip().lower()


def compact_text(value):
    return "".join(normalize_text(value).split())


def status_payload(status, message, x=0, y=0, width=0, height=0, confidence=0):
    return {
        "status": status,
        "message": message,
        "x": x,
        "y": y,
        "centerX": int(x + width / 2 + 0.5),
        "centerY": int(y + height / 2 + 0.5),
        "width": width,
        "height": height,
        "confidence": confidence,
        "evidenceRef": EVIDENCE_REF,
    }


def confidence_from_values(values):
    valid = []
    for value in values:
        try:
            number = float(value)
        except Exception:
            continue
        if number >= 0:
            valid.append(number / 100 if number > 1 else number)
    if not valid:
        return 0.5
    return max(0, min(1, sum(valid) / len(valid)))


def candidate_score(candidate_text, query, confidence):
    candidate = compact_text(candidate_text)
    target = compact_text(query)
    if not candidate or not target:
        return 0
    if candidate == target:
        return confidence
    if target in candidate:
        return confidence * 0.95
    return 0


def candidate_result(candidate, threshold):
    score = candidate["score"]
    status = "matched" if score >= threshold else "lowConfidence"
    message = "已找到目标。" if status == "matched" else "目标置信度不足。"
    return status_payload(
        status,
        message,
        x=candidate["x"],
        y=candidate["y"],
        width=candidate["width"],
        height=candidate["height"],
        confidence=score,
    )


def collect_candidates(data, query):
    texts = data.get("text", [])
    count = len(texts)
    candidates = []
    line_groups = {}
    for index in range(count):
        text = normalize_text(texts[index])
        if not text:
            continue
        try:
            x = int(float(data.get("left", [0] * count)[index]))
            y = int(float(data.get("top", [0] * count)[index]))
            width = int(float(data.get("width", [0] * count)[index]))
            height = int(float(data.get("height", [0] * count)[index]))
        except Exception:
            continue
        confidence = confidence_from_values([data.get("conf", [0] * count)[index]])
        score = candidate_score(text, query, confidence)
        if score > 0 and width > 0 and height > 0:
            candidates.append({
                "text": text,
                "x": x,
                "y": y,
                "width": width,
                "height": height,
                "score": score,
            })
        key = (
            data.get("block_num", [0] * count)[index],
            data.get("par_num", [0] * count)[index],
            data.get("line_num", [0] * count)[index],
        )
        group = line_groups.setdefault(key, {"texts": [], "xs": [], "ys": [], "rights": [], "bottoms": [], "conf": []})
        group["texts"].append(text)
        group["xs"].append(x)
        group["ys"].append(y)
        group["rights"].append(x + width)
        group["bottoms"].append(y + height)
        group["conf"].append(data.get("conf", [0] * count)[index])

    for group in line_groups.values():
        text = "".join(group["texts"])
        confidence = confidence_from_values(group["conf"])
        score = candidate_score(text, query, confidence)
        if score <= 0:
            continue
        x = min(group["xs"])
        y = min(group["ys"])
        right = max(group["rights"])
        bottom = max(group["bottoms"])
        if right > x and bottom > y:
            candidates.append({
                "text": text,
                "x": x,
                "y": y,
                "width": right - x,
                "height": bottom - y,
                "score": score,
            })
    return candidates


def locate_with_pytesseract(screen_bytes, query, threshold):
    if not package_available("pytesseract") or not package_available("PIL"):
        fail("unsupported", "OCR 视觉包不可用。")
    path = None
    try:
        from PIL import Image
        import pytesseract

        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as image_file:
            image_file.write(screen_bytes)
            path = image_file.name
        image = Image.open(path)
        data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
        candidates = collect_candidates(data, query)
        if not candidates:
            fail("notMatched", "未找到目标。")
        candidates.sort(key=lambda item: item["score"], reverse=True)
        emit(candidate_result(candidates[0], threshold))
    except SystemExit:
        raise
    except Exception:
        fail("unsupported", "OCR 视觉 API 暂不可用。")
    finally:
        if path:
            try:
                os.unlink(path)
            except Exception:
                pass


try:
    request = json.loads(sys.stdin.read())
    threshold = float(request.get("confidenceThreshold", 0.8))
    query = normalize_text(request.get("query", ""))
    screen_bytes = base64.b64decode(request["screenshotBase64"])
except Exception:
    fail("infrastructureError", "Python OCR 输入不可读。")

if not query:
    fail("infrastructureError", "文本目标缺少查询内容。")

locate_with_pytesseract(screen_bytes, query, threshold)
''';
