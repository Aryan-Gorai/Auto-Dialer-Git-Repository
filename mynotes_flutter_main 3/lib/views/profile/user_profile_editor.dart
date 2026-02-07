import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_validator/string_validator.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:flutter_application_1/models/app_user.dart';
import 'package:flutter_application_1/services/team_service.dart';
import 'package:flutter_application_1/models/team.dart';
// import 'package:email_validator/email_validator.dart';

class UserProfileEditor extends StatefulWidget {
  const UserProfileEditor({Key? key}) : super(key: key);

  @override
  _UserProfileEditorState createState() => _UserProfileEditorState();
}

class _UserProfileEditorState extends State<UserProfileEditor> {
  // Firestore profile doc (id = userId)
  late final String _userId;
  DocumentReference<Map<String, dynamic>>? _profileDoc;
  bool _loading = true;

  // Local state
  String _imageUrl = "";
  String _name = '';
  String _email = '';
  String _phone = '';
  String _about = '';
  String? _role;
  String? _teamId;
  String? _teamName;

  @override
  void initState() {
    super.initState();
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    _userId = user?.uid ?? '';
    _email = user?.email ?? '';
    if (_userId.isNotEmpty) {
      _profileDoc = FirebaseFirestore.instance.collection('user_profiles').doc(_userId);
      _loadOrInitProfile();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadOrInitProfile() async {
    try {
      final snapshot = await _profileDoc!.get();
      if (!snapshot.exists) {
        // initialize — role and team_id will be set later
        await _profileDoc!.set({
          'user_id': _userId,
          'name': 'Your Name',
          'email': _email,
          'phone': '',
          'about': '',
          'photoUrl': '',
          'role': null,
          'team_id': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _name = 'Your Name';
        _phone = '';
        _about = '';
        _imageUrl = '';
        _role = null;
        _teamId = null;
      } else {
        final data = snapshot.data()!;
        _name = (data['name'] ?? '').toString();
        _phone = (data['phone'] ?? '').toString();
        _about = (data['about'] ?? '').toString();
        _imageUrl = (data['photoUrl'] ?? '').toString();
        _role = data['role'] as String?;
        _teamId = data['team_id'] as String?;
      }
      // Load team name if user is in a team
      if (_teamId != null && _teamId!.isNotEmpty) {
        final team = await TeamService().getTeam(_teamId!);
        _teamName = team?.teamName;
      }
    } catch (_) {
      // ignore minimal
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveField(String field, dynamic value) async {
    if (_profileDoc == null) return;
    await _profileDoc!.set({
      field: value,
      'user_id': _userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 10,
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Edit Profile',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.headline3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(64, 105, 225, 1),
                    )
                  ),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              )
            else ...[
              InkWell(
                onTap: () {
                  navigateSecondPage(context, _EditImagePage(
                    userId: _userId,
                    initialUrl: _imageUrl,
                    onUploaded: (url) {
                      setState(() => _imageUrl = url);
                      _saveField('photoUrl', url);
                    },
                  ));
                },
                child: DisplayImage(
                  imagePath: _imageUrl.isEmpty ?
                    "https://ui-avatars.com/api/?name=${Uri.encodeComponent(_name.isEmpty ? 'User' : _name)}&background=DDD&color=555" :
                    _imageUrl,
                  onPressed: () {},
                ),
              ),
              _buildEditableInfoDisplay(_name, 'Name', _EditNameFormPage(
                initial: _name,
                onSaved: (val) {
                  setState(() => _name = val);
                  _saveField('name', val);
                },
              )),
              _buildEditableInfoDisplay(_phone.isEmpty ? 'Add phone' : _phone, 'Phone', _EditPhoneFormPage(
                initial: _phone,
                onSaved: (val) {
                  setState(() => _phone = val);
                  _saveField('phone', val);
                },
              )),
              _buildReadOnlyInfoDisplay(_email.isEmpty ? 'No email' : _email, 'Email'),
              // Role display
              if (_role != null)
                _buildReadOnlyInfoDisplay(
                  _role == 'team_owner' ? 'Team Owner' : 'Team Member',
                  'Role',
                ),
              const SizedBox(height: 10),
              // Team section
              _buildTeamSection(),
              _buildAbout(_about),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection() {
    if (_role == 'team_member') {
      // If member has a team, show team name and leave button
      if (_teamId != null && _teamId!.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team',
                style: AppleTypography.withAppleFont(
                  AppleTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _teamName ?? 'Team',
                        style: AppleTypography.withAppleFont(
                          AppleTypography.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _showLeaveTeamDialog,
                      child: const Text(
                        'Leave',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      // If member has no team, show join button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showJoinTeamDialog,
            icon: const Icon(Icons.group_add, size: 20),
            label: const Text('Join a Team'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
    }

    // Team Owner — show manage team hint (actual management is in the Team tab)
    if (_role == 'team_owner') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manage your team from the Team tab',
                  style: AppleTypography.withAppleFont(
                    AppleTypography.body2.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showJoinTeamDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the 6-character team code provided by your Team Owner:'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'e.g. ABC123',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a 6-character code')),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _loading = true);
              final team = await TeamService().joinTeam(_userId, code);
              if (!mounted) return;
              if (team != null) {
                setState(() {
                  _teamId = team.id;
                  _teamName = team.teamName;
                  _loading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Joined "${team.teamName}" successfully!')),
                );
              } else {
                setState(() => _loading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid code. Team not found.')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showLeaveTeamDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Team'),
        content: Text('Are you sure you want to leave "${_teamName ?? 'this team'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_teamId == null) return;
              setState(() => _loading = true);
              await TeamService().leaveTeam(_userId, _teamId!);
              if (!mounted) return;
              setState(() {
                _teamId = null;
                _teamName = null;
                _loading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have left the team.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoDisplay(String getValue, String title, Widget editPage) =>
      Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppleTypography.withAppleFont(
                AppleTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                )
              ),
            ),
            SizedBox(height: 1),
            Container(
              width: 350,
              height: 40,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey,
                    width: 1,
                  ),
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: TextButton(
                     onPressed: () {
                       navigateSecondPage(context, editPage);
                    },
                    child: Text(
                      getValue,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body1.copyWith(
                          height: 1.4,
                        )
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.grey,
                  size: 40.0,
                )
              ]),
            )
          ],
        ),
      );

  Widget _buildReadOnlyInfoDisplay(String value, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 1),
        Container(
          width: 350,
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey,
                width: 1,
              ),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            '  $value',
            style: AppleTypography.withAppleFont(
              AppleTypography.body1.copyWith(
                height: 1.4, 
                color: Colors.black87
              )
            ),
          ),
        )
      ],
    ),
  );

  Widget _buildAbout(String about) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell Us About Yourself',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 1),
        Container(
          width: 350,
          height: 200,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey,
                width: 1,
              ),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  navigateSecondPage(context, _EditDescriptionFormPage(
                    initial: about,
                    onSaved: (val) {
                      setState(() => _about = val);
                      _saveField('about', val);
                      _saveField('name', _name); // ensure linkage
                    },
                  ));
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      about.isEmpty ? 'Tap to add a short bio' : about,
                      style: AppleTypography.withAppleFont(
                        AppleTypography.body1.copyWith(
                          height: 1.4,
                        )
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right,
              color: Colors.grey,
              size: 40.0,
            )
          ]),
        )
      ],
    ),
  );

  FutureOr onGoBack(dynamic value) {
    setState(() {});
  }

  void navigateSecondPage(BuildContext ctx, Widget editForm) {
    Route route = MaterialPageRoute(builder: (context) => editForm);
    Navigator.push(ctx, route).then(onGoBack);
  }
}

// User data models and supporting classes
class User {
  String image;
  String name;
  String email;
  String phone;
  String aboutMeDescription;

  User({
    required this.image,
    required this.name,
    required this.email,
    required this.phone,
    required this.aboutMeDescription,
  });

  User copy({
    String? imagePath,
    String? name,
    String? phone,
    String? email,
    String? about,
  }) =>
      User(
        image: imagePath ?? this.image,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        aboutMeDescription: about ?? this.aboutMeDescription,
      );

  static User fromJson(Map<String, dynamic> json) => User(
    image: json['imagePath'],
    name: json['name'],
    email: json['email'],
    aboutMeDescription: json['about'],
    phone: json['phone'],
  );

  Map<String, dynamic> toJson() => {
    'imagePath': image,
    'name': name,
    'email': email,
    'about': aboutMeDescription,
    'phone': phone,
  };
}

class UserData {
  static late SharedPreferences _preferences;
  static const _keyUser = 'user';

  static User myUser = User(
    image: "https://upload.wikimedia.org/wikipedia/en/0/0b/Darth_Vader_in_The_Empire_Strikes_Back.jpg",
    name: 'Test Test',
    email: 'test.test@gmail.com',
    phone: '(208) 206-5039',
    aboutMeDescription: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat...',
  );

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setUser(User user) async {
    final json = jsonEncode(user.toJson());
    await _preferences.setString(_keyUser, json);
    myUser = user;
  }

  static User getUser() {
    final json = _preferences.getString(_keyUser);
    return json == null ? myUser : User.fromJson(jsonDecode(json));
  }
}

class DisplayImage extends StatelessWidget {
  final String imagePath;
  final VoidCallback onPressed;

  const DisplayImage({
    Key? key,
    required this.imagePath,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Color.fromRGBO(64, 105, 225, 1);

    return Center(
      child: Stack(children: [
        _buildImage(color),
        Positioned(
          child: _buildEditIcon(color),
          right: 4,
          top: 10,
        )
      ]),
    );
  }

  Widget _buildImage(Color color) {
    final image = imagePath.contains('https://')
        ? NetworkImage(imagePath)
        : FileImage(File(imagePath));

    return CircleAvatar(
      radius: 75,
      backgroundColor: color,
      child: CircleAvatar(
        backgroundImage: image as ImageProvider,
        radius: 70,
      ),
    );
  }

  Widget _buildEditIcon(Color color) => _buildCircle(
    all: 8,
    child: Icon(
      Icons.edit,
      color: color,
      size: 20,
    ),
  );

  Widget _buildCircle({
    required Widget child,
    required double all,
  }) =>
      ClipOval(
        child: Container(
          padding: EdgeInsets.all(all),
          color: Colors.white,
          child: child,
        ),
      );
}

// Edit Pages
class _EditNameFormPage extends StatefulWidget {
  final String initial;
  final void Function(String value) onSaved;
  const _EditNameFormPage({Key? key, required this.initial, required this.onSaved}) : super(key: key);

  @override
  _EditNameFormPageState createState() => _EditNameFormPageState();
}

class _EditNameFormPageState extends State<_EditNameFormPage> {
  final _formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final secondNameController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // try to split into first/last if possible
    final parts = widget.initial.trim().split(' ');
    if (parts.isNotEmpty) firstNameController.text = parts.first;
    if (parts.length > 1) secondNameController.text = parts.sublist(1).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
        leading: BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 330,
              child: const Text(
                "What's Your Name?",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 40, 16, 0),
                  child: SizedBox(
                    height: 100,
                    width: 150,
                    child: TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        } else if (!isAlpha(value)) {
                          return 'Only Letters Please';
                        }
                        return null;
                      },
                      decoration: InputDecoration(labelText: 'First Name'),
                      controller: firstNameController,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 40, 16, 0),
                  child: SizedBox(
                    height: 100,
                    width: 150,
                    child: TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        } else if (!isAlpha(value)) {
                          return 'Only Letters Please';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      controller: secondNameController,
                    ),
                  ),
                )
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 150),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 330,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate() &&
                          isAlpha(firstNameController.text + secondNameController.text)) {
                        final name = (firstNameController.text + " " + secondNameController.text).trim();
                        widget.onSaved(name);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _EditPhoneFormPage extends StatefulWidget {
  final String initial;
  final void Function(String value) onSaved;
  const _EditPhoneFormPage({Key? key, required this.initial, required this.onSaved}) : super(key: key);

  @override
  _EditPhoneFormPageState createState() => _EditPhoneFormPageState();
}

class _EditPhoneFormPageState extends State<_EditPhoneFormPage> {
  final _formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    phoneController.text = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
        leading: BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: Text(
                "What's Your Phone Number?",
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: SizedBox(
                height: 100,
                width: 320,
                child: TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    } else if (isAlpha(value)) {
                      return 'Only Numbers Please';
                    } else if (value.length < 10) {
                      return 'Please enter a VALID phone number';
                    }
                    return null;
                  },
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Your Phone Number',
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 150),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 320,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && isNumeric(phoneController.text)) {
                        widget.onSaved(phoneController.text);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Email is read-only from FirebaseAuth; edit page removed.

class _EditImagePage extends StatefulWidget {
  final String userId;
  final String initialUrl;
  final void Function(String url) onUploaded;
  const _EditImagePage({Key? key, required this.userId, required this.initialUrl, required this.onUploaded}) : super(key: key);

  @override
  _EditImagePageState createState() => _EditImagePageState();
}

class _EditImagePageState extends State<_EditImagePage> {
  String _previewPath = '';
  bool _uploading = false;

  Future<void> _pickCropUpload() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return; // user cancelled

      String path = picked.path;
      // Try crop; if cropper isn't available or user cancels, fall back to picked image.
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          uiSettings: [
            IOSUiSettings(title: 'Crop Photo'),
            AndroidUiSettings(toolbarTitle: 'Crop Photo'),
          ],
        );
        if (cropped != null) {
          path = cropped.path;
        }
      } catch (_) {
        // ignore crop errors and proceed with original image
      }

      if (!mounted) return;
      setState(() => _previewPath = path);

      // Immediately upload and finish for a snappier UX
      await _uploadAndFinish(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select photo: $e')),
      );
    }
  }

  Future<void> _uploadAndFinish(String path) async {
    try {
      if (!mounted) return;
      setState(() => _uploading = true);
      // show a simple progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final file = File(path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures/${widget.userId}.jpg');
      // Add a timeout to avoid endless spinner if network or permissions hang
      await storageRef
          .putFile(file, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 60));
      final url = await storageRef.getDownloadURL();

      if (!mounted) return;
      Navigator.of(context).pop(); // close progress dialog
      setState(() => _uploading = false);

      widget.onUploaded(url);
      if (mounted) Navigator.pop(context); // close editor
    } on TimeoutException {
      if (!mounted) return;
      if (_uploading) {
        Navigator.of(context).pop();
      }
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload timed out. Please check your network and try again.')),
      );
    } catch (e) {
      if (!mounted) return;
      // Ensure dialog closed if showing
      if (_uploading) {
        Navigator.of(context).pop();
      }
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
        leading: BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 330,
                  child: const Text(
                    "Upload a photo of yourself:",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GestureDetector(
                  onTap: _pickCropUpload,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _previewPath.isEmpty
                        ? (widget.initialUrl.isNotEmpty
                            ? AspectRatio(
                                aspectRatio: 1,
                                child: Image.network(
                                  widget.initialUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                height: 200,
                                color: Colors.grey[200],
                                alignment: Alignment.center,
                                child: const Text('Tap to choose a photo'),
                              ))
                        : AspectRatio(
                            aspectRatio: 1,
                            child: Image.file(
                              File(_previewPath),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 330,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_previewPath.isEmpty) {
                      await _pickCropUpload();
                    } else {
                      await _uploadAndFinish(_previewPath);
                    }
                  },
                  child: const Text(
                    'Save Photo',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditDescriptionFormPage extends StatefulWidget {
  final String initial;
  final void Function(String value) onSaved;
  const _EditDescriptionFormPage({Key? key, required this.initial, required this.onSaved}) : super(key: key);

  @override
  _EditDescriptionFormPageState createState() => _EditDescriptionFormPageState();
}

class _EditDescriptionFormPageState extends State<_EditDescriptionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    descriptionController.text = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
        leading: BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 350,
              child: Text(
                "What type of passenger\nare you?",
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline4.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                height: 250,
                width: 350,
                child: TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length > 200) {
                      return 'Please describe yourself but keep it under 200 characters.';
                    }
                    return null;
                  },
                  controller: descriptionController,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.fromLTRB(10, 15, 10, 100),
                    hintMaxLines: 3,
                    hintText:
                    'Write a little bit about yourself. Do you like chatting? Are you a smoker? Do you bring pets with you? Etc.',
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 50),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 350,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSaved(descriptionController.text);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Update',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}