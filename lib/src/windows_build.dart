import 'dart:io';
import 'package:cli_util/cli_logging.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'method_extensions.dart';
import 'configuration.dart';

/// Handles windows files build steps
class WindowsBuild {
  final Logger _logger = GetIt.I<Logger>();
  final Configuration _config = GetIt.I<Configuration>();

  /// Run "flutter build windows" command
  Future<void> build() async {
    final flutterBuildArgs = [
      'build',
      'windows',
      ...?_config.windowsBuildArgs,
      if (_config.createWithDebugBuildFiles) '--debug',
    ];

    final flutterCommand = await _getFlutterCommand(_config.useFvm);
    final String executable = flutterCommand.executable;
    final List<String> arguments = [
      ...flutterCommand.arguments,
      ...flutterBuildArgs,
    ];

    final Progress loggerProgress = _logger.progress(
      'running "${flutterCommand.displayName} ${flutterBuildArgs.join(' ')}"',
    );

    _logger.trace(
      'build windows files with the command: '
      '"$executable ${arguments.join(' ')}"',
    );

    ProcessResult buildProcess = await Process.run(
      executable,
      arguments,
      runInShell: true,
    );

    buildProcess.exitOnError();

    loggerProgress.finish(showTiming: true);
  }
}

/// Represents a flutter command with its executable and arguments
class _FlutterCommand {
  final String executable;
  final List<String> arguments;
  final String displayName;

  _FlutterCommand({
    required this.executable,
    this.arguments = const [],
    required this.displayName,
  });
}

Future<_FlutterCommand> _getFlutterCommand(bool configUseFvm) async {
  // Check configuration first
  if (configUseFvm) {
    return _FlutterCommand(
      executable: 'fvm',
      arguments: ['flutter'],
      displayName: 'fvm flutter',
    );
  }

  // Check environment variable override
  final useFvm = Platform.environment['MSIX_USE_FVM']?.toLowerCase();
  if (useFvm == 'true') {
    return _FlutterCommand(
      executable: 'fvm',
      arguments: ['flutter'],
      displayName: 'fvm flutter',
    );
  }
  if (useFvm == 'false') {
    final flutterPath = await _getDirectFlutterPath();
    return _FlutterCommand(executable: flutterPath, displayName: 'flutter');
  }

  // Check if project uses FVM (has .fvmrc or .fvm/flutter_sdk)
  final currentDir = Directory.current.path;
  final fvmrcPath = p.join(currentDir, '.fvmrc');
  final fvmSdkPath = p.join(currentDir, '.fvm', 'flutter_sdk');

  if (await File(fvmrcPath).exists() || await Directory(fvmSdkPath).exists()) {
    return _FlutterCommand(
      executable: 'fvm',
      arguments: ['flutter'],
      displayName: 'fvm flutter',
    );
  }

  // Fallback: try to auto-detect FVM from dart executable path
  final flutterPath = await _getDirectFlutterPath();
  return _FlutterCommand(executable: flutterPath, displayName: 'flutter');
}

Future<String> _getDirectFlutterPath() async {
  // use environment-variable 'flutter' by default
  var flutterPath = 'flutter';

  // e.g. C:\Users\MyUser\fvm\versions\3.7.12\bin\cache\dart-sdk\bin\dart.exe
  final dartPath = p.split(Platform.executable);

  // if contains 'cache\dart-sdk' we can know where is the 'flutter' located
  if (dartPath.contains('dart-sdk') && dartPath.length > 4) {
    // e.g. C:\Users\MyUser\fvm\versions\3.7.12\bin\flutter
    final flutterRelativePath = p.joinAll([
      ...dartPath.sublist(0, dartPath.length - 4),
      'flutter',
    ]);

    if (await File(flutterRelativePath).exists()) {
      flutterPath = flutterRelativePath;
    }
  }

  return flutterPath;
}
