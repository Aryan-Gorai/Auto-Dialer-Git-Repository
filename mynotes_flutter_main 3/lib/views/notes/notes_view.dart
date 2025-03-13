// import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/routes.dart';
import 'package:flutter_application_1/enums/menu_action.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/auth/bloc/auth_bloc.dart';
import 'package:flutter_application_1/services/auth/bloc/auth_event.dart';
import 'package:flutter_application_1/services/cloud/cloud_note.dart';
import 'package:flutter_application_1/services/cloud/firebase_cloud_storage.dart';
import 'package:flutter_application_1/utilities/dialogs/logout_dialog.dart';
import 'package:flutter_application_1/views/notes/notes_list_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:flutter_application_1/views/call/call_view.dart';
import 'package:flutter_application_1/views/list/firebase_services.dart';

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {


//CODE TO GET CURRENT PAGE
    String getCurrentScreen(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) {
      return route.settings.name ?? '';
    }
    return '';
  }
//CODE TO GET CURRENT PAGE




  late final FirebaseCloudStorage _notesService;
  String get userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    _notesService = FirebaseCloudStorage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Notes'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(createOrUpdateNoteRoute);
            },
            icon: const Icon(Icons.add),
          ),
          IconButton( // To take to call view
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CallView(),
                ),
              );
            },
            icon:  Icon(Icons.add_circle, size: 37),

          ),

          //new button
          IconButton( // to test neumorphic
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CallView(),
                ),
              );
            },
            icon: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.add_circle,
              size: 40,
              color: Colors.white,
            ),
            ),
          ),


          PopupMenuButton<MenuAction>(
            onSelected: (value) async {
              switch (value) {
                case MenuAction.logout:
                  final shouldLogout = await showLogOutDialog(context);
                  if (shouldLogout) {
                    context.read<AuthBloc>().add(
                          const AuthEventLogOut(),
                        );
                  }
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<MenuAction>(
                  value: MenuAction.logout,
                  child: Text('Log out'),
                ),
              ];
            },
          )
        ],
      ),
      body: StreamBuilder(
        stream: _notesService.allNotes(ownerUserId: userId),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
            case ConnectionState.active:
              if (snapshot.hasData) {
                final allNotes = snapshot.data as Iterable<CloudNote>;
                return NotesListView(
                  notes: allNotes,
                  onDeleteNote: (note) async {
                    await _notesService.deleteNote(documentId: note.documentId);
                  },
                  onTap: (note) {
                    Navigator.of(context).pushNamed(
                      createOrUpdateNoteRoute,
                      arguments: note,
                      
                     
                    );
                    
                    
                  },
                );
              } else {
                return const CircularProgressIndicator();
              }
            default:
              return const CircularProgressIndicator();
          }
        },
      ),

      //bottomNavigationBar: buildBottomNavigationBar(context), // Call the function here
      bottomNavigationBar: Gbar(),
      );
      
  }
}