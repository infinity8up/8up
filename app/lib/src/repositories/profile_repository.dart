import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'image_storage_repository.dart';

class ProfileRepository {
  ProfileRepository(this._client, this._imageStorage);

  final SupabaseClient _client;
  final ImageStorageRepository _imageStorage;

  Future<UserProfile?> fetchCurrentUserProfile() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromMap(response);
  }

  Future<void> updateProfile({
    required UserProfile currentProfile,
    required String name,
    required String phone,
    required String email,
    PickedImageFile? imageFile,
    bool removeImage = false,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final normalizedEmail = email.trim().toLowerCase();
    String? resolvedImageUrl = currentProfile.imageUrl;
    final userImagePath = _imageStorage.userObjectPath(
      currentProfile.memberCode,
    );
    var removeStoredImageAfterSave = false;
    final syncedEmail =
        (_client.auth.currentUser?.email ?? currentProfile.email ?? normalizedEmail)
            .trim()
            .toLowerCase();

    if (removeImage) {
      resolvedImageUrl = null;
      removeStoredImageAfterSave = true;
    } else if (imageFile != null) {
      resolvedImageUrl = await _imageStorage.uploadUserImage(
        memberCode: currentProfile.memberCode,
        file: imageFile,
      );
    }

    await _client
        .from('users')
        .update({
          'name': name,
          'phone': phone,
          'email': syncedEmail,
          'image_url': resolvedImageUrl,
        })
        .eq('id', userId);

    if (removeStoredImageAfterSave) {
      await _imageStorage.removeObject(userImagePath);
    }
  }
}
