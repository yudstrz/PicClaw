import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateState {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isLoading;
  final String? errorMessage;

  const UpdateState({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isLoading,
    this.errorMessage,
  });

  factory UpdateState.initial() => const UpdateState(
        isUpdateAvailable: false,
        latestVersion: '',
        downloadUrl: '',
        releaseNotes: '',
        isLoading: false,
      );

  UpdateState copyWith({
    bool? isUpdateAvailable,
    String? latestVersion,
    String? downloadUrl,
    String? releaseNotes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UpdateState(
      isUpdateAvailable: isUpdateAvailable ?? this.isUpdateAvailable,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(UpdateState.initial()) {
    checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Get current local app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String localVersion = packageInfo.version;

      // 2. Fetch latest release from GitHub API
      final url = Uri.parse('https://api.github.com/repos/yudstrz/PicClaw/releases/latest');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String tagVersion = data['tag_name'] as String; // e.g., "v1.1.0"
        final String body = data['body'] as String? ?? '';
        final List<dynamic> assets = data['assets'] as List<dynamic>? ?? [];
        
        // Find APK in assets
        String downloadUrl = data['html_url'] as String; // Fallback to release page
        for (var asset in assets) {
          final String name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }

        // Clean version string (remove 'v' prefix if present)
        final String cleanLatestVersion = tagVersion.startsWith('v') 
            ? tagVersion.substring(1) 
            : tagVersion;
        final String cleanLocalVersion = localVersion.startsWith('v') 
            ? localVersion.substring(1) 
            : localVersion;

        // 3. Compare versions using simple SemVer logic
        final bool updateAvailable = _isVersionNewer(cleanLocalVersion, cleanLatestVersion);

        state = state.copyWith(
          isUpdateAvailable: updateAvailable,
          latestVersion: tagVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
          isLoading: false,
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  bool _isVersionNewer(String local, String latest) {
    if (local == latest) return false;
    final List<int> localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad lists to equal lengths
    while (localParts.length < 3) {
      localParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > localParts[i]) return true;
      if (latestParts[i] < localParts[i]) return false;
    }
    return false;
  }
}

final updateCheckerProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});
