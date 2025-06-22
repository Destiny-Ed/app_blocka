import 'package:flutter_test/flutter_test.dart';
import 'package:app_blocka/app_blocka.dart';
import 'package:app_blocka/app_blocka_platform_interface.dart';
import 'package:app_blocka/app_blocka_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAppBlockaPlatform
    with MockPlatformInterfaceMixin
    implements AppBlockaPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AppBlockaPlatform initialPlatform = AppBlockaPlatform.instance;

  test('$MethodChannelAppBlocka is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppBlocka>());
  });

  test('getPlatformVersion', () async {
    AppBlocka appBlockaPlugin = AppBlocka();
    MockAppBlockaPlatform fakePlatform = MockAppBlockaPlatform();
    AppBlockaPlatform.instance = fakePlatform;

    expect(await appBlockaPlugin.getPlatformVersion(), '42');
  });
}
