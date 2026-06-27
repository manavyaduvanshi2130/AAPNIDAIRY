import 'dart:convert';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';

class DriveService {
  static const _backupFileName = "aappni_dairy_backup.json";

  // Google Drive AppData folder ka access mangna
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  Future<drive.DriveApi?> _getDriveApi() async {
    final googleUser = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final httpClient = (await _googleSignIn.authenticatedClient())!;
    return drive.DriveApi(httpClient);
  }

  // Backup Upload Karne ke liye
  Future<bool> uploadBackup(Map<String, dynamic> data) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // JSON file create karein temporary location pe
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$_backupFileName');
      await file.writeAsString(jsonEncode(data));

      // Check karein ki pehle se koi backup hai kya
      final query = "name = '$_backupFileName' and trashed = false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      final media = drive.Media(file.openRead(), file.lengthSync());
      final driveFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Purani file ko update karein
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        // Nayi file create karein
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
      return true;
    } catch (e) {
      print("Upload Error: $e");
      return false;
    }
  }

  // Backup Download Karne ke liye
  Future<Map<String, dynamic>?> downloadBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      // Backup file search karein
      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) return null;

      final fileId = fileList.files!.first.id!;

      // File download karein
      final drive.Media response = await driveApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;

      List<int> dataStore = [];
      await for (final data in response.stream) {
        dataStore.addAll(data);
      }

      final String content = utf8.decode(dataStore);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print("Download Error: $e");
      return null;
    }
  }
}