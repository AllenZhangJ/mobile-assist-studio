import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:test/test.dart';

void main() {
  test('reads Appium status from a local server', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) {
        expect(request.uri.path, '/status');
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'value': {'ready': true, 'message': 'ready'},
            }),
          )
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));

    final status = await client.status();
    expect(status.ready, isTrue);
    expect(status.message, 'ready');

    client.close(force: true);
    await server.close(force: true);
  });

  test('maps socket failures into AppiumClientException', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);

    final client = AppiumClient(
      config: AppiumServerConfig(
        port: port,
        timeout: const Duration(milliseconds: 100),
      ),
    );

    expect(client.status, throwsA(isA<AppiumClientException>()));
    client.close(force: true);
  });

  test('preserves WebDriver error message on HTTP failures', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) {
        expect(request.method, 'POST');
        expect(request.uri.path, '/session');
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'value': {
                'error': 'unknown error',
                'message': 'Unknown device or simulator UDID: device-id',
              },
            }),
          )
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));

    await expectLater(
      client.createSession(
        const AppiumSessionRequest(capabilities: {'platformName': 'iOS'}),
      ),
      throwsA(
        isA<AppiumClientException>().having(
          (error) => error.message,
          'message',
          contains('Unknown device or simulator UDID'),
        ),
      ),
    );

    client.close(force: true);
    await server.close(force: true);
  });

  test('creates and deletes a WebDriver session', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      if (request.method == 'POST' && request.uri.path == '/session') {
        final body = await utf8.decodeStream(request);
        final payload = jsonDecode(body) as Map<String, Object?>;
        expect(payload['capabilities'], isA<Map<String, Object?>>());
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'value': {
                'sessionId': 'session-1234',
                'capabilities': {'platformName': 'iOS'},
              },
            }),
          )
          ..close();
        return;
      }
      if (request.method == 'DELETE' &&
          request.uri.path == '/session/session-1234') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
        return;
      }
      request.response
        ..statusCode = 404
        ..close();
    });

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));
    final session = await client.createSession(
      const AppiumSessionRequest(capabilities: {'platformName': 'iOS'}),
    );
    await client.deleteSession(session.id);

    expect(session.id, 'session-1234');
    expect(session.capabilities['platformName'], 'iOS');
    expect(requests, ['POST /session', 'DELETE /session/session-1234']);

    client.close(force: true);
    await subscription.cancel();
    await server.close(force: true);
  });

  test('reads screenshot base64 from a WebDriver session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) {
        expect(request.method, 'GET');
        expect(request.uri.path, '/session/session-1234/screenshot');
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': 'base64-screenshot'}))
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));
    final screenshot = await client.screenshot('session-1234');

    expect(screenshot, 'base64-screenshot');

    client.close(force: true);
    await server.close(force: true);
  });

  test('reads page source from a WebDriver session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) {
        expect(request.method, 'GET');
        expect(request.uri.path, '/session/session-1234/source');
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': '<App><Button name="OK"/></App>'}))
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));
    final source = await client.pageSource('session-1234');

    expect(source, contains('Button'));

    client.close(force: true);
    await server.close(force: true);
  });

  test('reads viewport size from window rect', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) {
        expect(request.method, 'GET');
        expect(request.uri.path, '/session/session-1234/window/rect');
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'value': {'x': 0, 'y': 0, 'width': 393, 'height': 852},
            }),
          )
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));
    final size = await client.viewportSize('session-1234');

    expect(size.width, 393);
    expect(size.height, 852);

    client.close(force: true);
    await server.close(force: true);
  });

  test('performs viewport tap and releases actions', () async {
    final requests = <String>[];
    Map<String, Object?>? tapPayload;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      if (request.method == 'POST' &&
          request.uri.path == '/session/session-1234/actions') {
        final body = await utf8.decodeStream(request);
        tapPayload = jsonDecode(body) as Map<String, Object?>;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
        return;
      }
      if (request.method == 'DELETE' &&
          request.uri.path == '/session/session-1234/actions') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
        return;
      }
      request.response
        ..statusCode = 404
        ..close();
    });

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));

    await client.tap(
      'session-1234',
      point: const ViewportPoint(x: 92, y: 499),
      durationMs: 80,
    );
    await client.releaseActions('session-1234');

    expect(requests, [
      'POST /session/session-1234/actions',
      'DELETE /session/session-1234/actions',
    ]);
    final actions = tapPayload?['actions'] as List<Object?>;
    final pointer = actions.single as Map<String, Object?>;
    expect(pointer['type'], 'pointer');
    expect(pointer['parameters'], {'pointerType': 'touch'});
    final pointerActions = pointer['actions'] as List<Object?>;
    expect(pointerActions[0], {
      'type': 'pointerMove',
      'duration': 0,
      'origin': 'viewport',
      'x': 92,
      'y': 499,
    });
    expect(pointerActions[2], {'type': 'pause', 'duration': 80});

    client.close(force: true);
    await subscription.cancel();
    await server.close(force: true);
  });

  test('performs viewport swipe and sends text input', () async {
    final requests = <String>[];
    Map<String, Object?>? swipePayload;
    Map<String, Object?>? inputPayload;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      if (request.method == 'POST' &&
          request.uri.path == '/session/session-1234/actions') {
        final body = await utf8.decodeStream(request);
        swipePayload = jsonDecode(body) as Map<String, Object?>;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
        return;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/session/session-1234/keys') {
        final body = await utf8.decodeStream(request);
        inputPayload = jsonDecode(body) as Map<String, Object?>;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
        return;
      }
      request.response
        ..statusCode = 404
        ..close();
    });

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));

    await client.swipe(
      'session-1234',
      from: const ViewportPoint(x: 200, y: 700),
      to: const ViewportPoint(x: 200, y: 300),
      durationMs: 450,
    );
    await client.inputText('session-1234', text: 'hello');

    expect(requests, [
      'POST /session/session-1234/actions',
      'POST /session/session-1234/keys',
    ]);
    final actions = swipePayload?['actions'] as List<Object?>;
    final pointer = actions.single as Map<String, Object?>;
    final pointerActions = pointer['actions'] as List<Object?>;
    expect(pointerActions[0], {
      'type': 'pointerMove',
      'duration': 0,
      'origin': 'viewport',
      'x': 200,
      'y': 700,
    });
    expect(pointerActions[2], {
      'type': 'pointerMove',
      'duration': 450,
      'origin': 'viewport',
      'x': 200,
      'y': 300,
    });
    expect(inputPayload, {
      'text': 'hello',
      'value': ['h', 'e', 'l', 'l', 'o'],
    });

    client.close(force: true);
    await subscription.cancel();
    await server.close(force: true);
  });

  test('performs viewport pinch with two touch pointers', () async {
    Map<String, Object?>? pinchPayload;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/session/session-1234/actions');
        final body = await utf8.decodeStream(request);
        pinchPayload = jsonDecode(body) as Map<String, Object?>;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));

    await client.pinch(
      'session-1234',
      firstFrom: const ViewportPoint(x: 180, y: 400),
      firstTo: const ViewportPoint(x: 90, y: 400),
      secondFrom: const ViewportPoint(x: 220, y: 400),
      secondTo: const ViewportPoint(x: 310, y: 400),
      durationMs: 420,
    );

    final actions = pinchPayload?['actions'] as List<Object?>;
    expect(actions, hasLength(2));
    final firstPointer = actions[0] as Map<String, Object?>;
    final secondPointer = actions[1] as Map<String, Object?>;
    expect(firstPointer['id'], 'finger1');
    expect(secondPointer['id'], 'finger2');
    expect(firstPointer['parameters'], {'pointerType': 'touch'});
    expect(secondPointer['parameters'], {'pointerType': 'touch'});
    final firstActions = firstPointer['actions'] as List<Object?>;
    final secondActions = secondPointer['actions'] as List<Object?>;
    expect(firstActions[0], {
      'type': 'pointerMove',
      'duration': 0,
      'origin': 'viewport',
      'x': 180,
      'y': 400,
    });
    expect(firstActions[2], {
      'type': 'pointerMove',
      'duration': 420,
      'origin': 'viewport',
      'x': 90,
      'y': 400,
    });
    expect(secondActions[0], {
      'type': 'pointerMove',
      'duration': 0,
      'origin': 'viewport',
      'x': 220,
      'y': 400,
    });
    expect(secondActions[2], {
      'type': 'pointerMove',
      'duration': 420,
      'origin': 'viewport',
      'x': 310,
      'y': 400,
    });

    client.close(force: true);
    await server.close(force: true);
  });

  test('presses whitelisted mobile home button', () async {
    Map<String, Object?>? payload;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/session/session-1234/execute/sync');
        final body = await utf8.decodeStream(request);
        payload = jsonDecode(body) as Map<String, Object?>;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'value': null}))
          ..close();
      }),
    );

    final client = AppiumClient(config: AppiumServerConfig(port: server.port));

    await client.pressButton('session-1234', button: AppiumMobileButton.home);

    expect(payload, {
      'script': 'mobile: pressButton',
      'args': [
        {'name': 'home'},
      ],
    });

    client.close(force: true);
    await server.close(force: true);
  });
}
