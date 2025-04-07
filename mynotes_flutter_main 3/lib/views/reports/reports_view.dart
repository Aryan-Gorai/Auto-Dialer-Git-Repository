import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/enums/menu_action.dart';
import 'package:flutter_application_1/utilities/dialogs/logout_dialog.dart';

import '../dialer/dialer.dart';
import '../list/firebase_services.dart';
import 'bar_graph/bar_graph.dart';
import 'heatmap/call_heatmap.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({Key? key}) : super(key: key);

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  int _page = 0;
  GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  
  // Heatmap settings
  String _selectedTimeScale = 'month'; // 'month', 'week', 'day'
  int _maxCallThreshold = 10; // Default max threshold
  final TextEditingController _thresholdController = TextEditingController(text: '10');
  bool _showHeatmap = true;
  int _timeOffset = 0; // 0 = current period, -1 = previous, 1 = next, etc.





   @override
  void initState() {
    super.initState();
    fetchALLData();
    _loadHeatmapSettings();
    _thresholdController.addListener(_updateThresholdAndSave);
  }
  
  // Load heatmap settings from Firebase
  Future<void> _loadHeatmapSettings() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot snapshot = await firestore
          .collection('user_settings')
          .doc(userId)
          .get();
      
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        
        setState(() {
          if (data.containsKey('heatmap_time_scale')) {
            _selectedTimeScale = data['heatmap_time_scale'];
          }
          
          if (data.containsKey('heatmap_max_threshold')) {
            _maxCallThreshold = data['heatmap_max_threshold'];
            _thresholdController.text = _maxCallThreshold.toString();
          }
          
          if (data.containsKey('heatmap_visible')) {
            _showHeatmap = data['heatmap_visible'];
          }
        });
        
        print('Heatmap settings loaded from Firebase');
      }
    } catch (e) {
      print('Error loading heatmap settings: $e');
    }
  }
  
  // Save heatmap settings to Firebase
  Future<void> _saveHeatmapSettings() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      await firestore
          .collection('user_settings')
          .doc(userId)
          .set({
            'heatmap_time_scale': _selectedTimeScale,
            'heatmap_max_threshold': _maxCallThreshold,
            'heatmap_visible': _showHeatmap,
            'last_updated': Timestamp.now(),
          }, SetOptions(merge: true));
      
      print('Heatmap settings saved to Firebase');
    } catch (e) {
      print('Error saving heatmap settings: $e');
    }
  }
  
  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }
  
  void _updateThresholdAndSave() {
    final value = int.tryParse(_thresholdController.text);
    if (value != null && value > 0) {
      setState(() {
        _maxCallThreshold = value;
      });
      // Save settings to Firebase
      _saveHeatmapSettings();
    }
  }
  
  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
    // Save settings to Firebase
    _saveHeatmapSettings();
  }


  List<double> weeklySummary = [];
  List<double> listIndexDouble = [];
  List<double> listTotalDocumentsDouble = [];
  List<double> listPercentages = [];
  List<String> listNames = [];

  bool shouldShowGraph = false;



  Future<List<double>> fetchALLData() async {
    await getListIndex();
    await getListTotalDocuments();
    await calculatePercentages();
    await getListNames();
    return weeklySummary;
  }




 Future<void> calculatePercentages() async {
  if (listIndexDouble.length != listTotalDocumentsDouble.length) {
    print("Error: Arrays have different lengths.");
    return;
  }

  List<double> newWeeklySummary = [];

  for (int i = 0; i < listIndexDouble.length; i++) {
    if (listTotalDocumentsDouble[i] != 0) {
      double newValue = (listIndexDouble[i] / listTotalDocumentsDouble[i]) * 100;
      newWeeklySummary.add(newValue);
    } else {
      newWeeklySummary.add(0);
    }
  }

  setState(() {
    weeklySummary = newWeeklySummary;
  });

  print("Weekly Summary: $weeklySummary");
}




  Future<void> getListNames() async {
    //FirebaseFirestore firestore = FirebaseFirestore.instance;
    //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();


        QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('lists_collection')
        .where('user_id', isEqualTo: userId)
        .get();


    List<String> names = snapshot.docs.map((DocumentSnapshot doc) {
      return doc.get('list_name') as String;
    }).toList();
    

    setState(() {
      listNames = names;
    });
  }













  Future<void> getListIndex() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

        QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('lists_collection')
        .where('user_id', isEqualTo: userId)
        .get();



    List<int> listIndex = snapshot.docs.map((DocumentSnapshot doc) {
      return doc.get('current_index') as int;
    }).toList();

    // Convert the listIndex values to double and update weeklySummary
    // weeklySummary = listIndex.map((int value) => value.toDouble()).toList();
    listIndexDouble = listIndex.map((int value) => value.toDouble()).toList();

    print(listIndex);

    // Trigger a rebuild of the UI
    setState(() {});
  }


  List<int> listTotalDocuments = [];
  Future<void> getListTotalDocuments() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    //QuerySnapshot snapshot = await firestore.collection('lists_collection').get();

        QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('lists_collection')
        .where('user_id', isEqualTo: userId)
        .get();




    List<int> index = snapshot.docs.map((DocumentSnapshot doc) {
      return doc.get('total_documents') as int;
    }).toList();

      
      listTotalDocuments = index;
      listTotalDocumentsDouble = listTotalDocuments.map((int value) => value.toDouble()).toList();

      print(listTotalDocuments);
    setState(() {
     
    });
  }





  void toggleGraphVisibility() {
    setState(() {
      shouldShowGraph = !shouldShowGraph;
    });
  }

  @override
  Widget build(BuildContext context) {





    return Scaffold(
      // bottomNavigationBar: Gbar(),
      //bottomNavigationBar: buildCurvedNavigationBar(),
      backgroundColor: Color.fromRGBO(248, 225, 209, 1),
      
      appBar: AppBar(
        title: Text("Reports View (% Completion)"),
        actions: [
          PopupMenuButton(
            onSelected: (value) async {
              switch (value){

                case MenuAction.logout:
                  final shouldLogout = await showLogOutDialog(context);
                  if (shouldLogout) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login/',
                    (_) => false,
                    );
                  }
              }
            },
            itemBuilder: (context) {
              return const [  
                 PopupMenuItem<MenuAction>(

                value: MenuAction.logout, 
                child: Text("Log out"),
              
              ),
        ]; 
                

            }
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[



            // ElevatedButton(
            //   onPressed: toggleGraphVisibility,
            //   style: ElevatedButton.styleFrom(
            //     primary: Colors.grey[200], // Background color
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(8.0),
            //     ),
            //     padding: const EdgeInsets.all(12.0),
            //   ),
            //   child: Text(
            //     "Draw Graph",
            //     style: TextStyle(color: textColor(context)),
            //   ),
            // ),





            // ElevatedButton(
            //   onPressed: () async {
                        
            //     setState(() {
            //       shouldShowGraph = false;
            //     });
            //     fetchALLData();
            //   },
            //   style: ElevatedButton.styleFrom(
            //     primary: Colors.grey[200], // Background color
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(8.0),
            //     ),
            //     padding: const EdgeInsets.all(12.0),
            //   ),
            //   child: Text(
            //     "Get List Data",
            //     style: TextStyle(color: textColor(context)),
            //   ),
            // ),




            if (shouldShowGraph)
              SizedBox(
                height: 400,
                child: MyBarGraph(weeklySummary: weeklySummary),
              ),
               SizedBox(height: 20), // Add spacing between buttons and listNames display
            if (listNames.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  listNames.length,
                  (index) => Text("$index: ${listNames[index]}"),
                ),
              ),




            // Call Heatmap Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Call Frequency Heatmap",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Time scale selector
                        Row(
                          children: [
                            Text(
                              "Time Scale:",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 16),
                            DropdownButton<String>(
                              value: _selectedTimeScale,
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedTimeScale = newValue;
                                  });
                                  // Save settings to Firebase
                                  _saveHeatmapSettings();
                                }
                              },
                              items: <String>['month', 'week', 'day']
                                  .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value[0].toUpperCase() + value.substring(1)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Max threshold input
                        Row(
                          children: [
                            Text(
                              "Max Call Threshold:",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _thresholdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Toggle and refresh buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                // Force refresh of the heatmap
                                setState(() {
                                  // This will trigger a rebuild of the CallHeatmap widget
                                  _showHeatmap = false;
                                });
                                // Small delay to ensure the widget is removed before showing it again
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  setState(() {
                                    _showHeatmap = true;
                                  });
                                });
                              },
                              child: const Text(
                                "Refresh Data",
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                            TextButton(
                              onPressed: _toggleHeatmap,
                              child: Text(
                                _showHeatmap ? "Hide Heatmap" : "Show Heatmap",
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Navigation buttons and heatmap
                  if (_showHeatmap)
                    Column(
                      children: [
                        // Navigation buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: () {
                                setState(() {
                                  _timeOffset--; // Go to previous period
                                });
                              },
                              tooltip: 'Previous ${_selectedTimeScale}',
                            ),
                            const SizedBox(width: 20),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _timeOffset = 0; // Reset to current period
                                });
                              },
                              child: const Text('Current'),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () {
                                setState(() {
                                  _timeOffset++; // Go to next period
                                });
                              },
                              tooltip: 'Next ${_selectedTimeScale}',
                            ),
                          ],
                        ),
                        // Heatmap
                        SizedBox(
                          height: 350,
                          child: CallHeatmap(
                            timeScale: _selectedTimeScale,
                            maxCallThreshold: _maxCallThreshold,
                            timeOffset: _timeOffset,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // Original Completion Card
            Row(
              children: <Widget>[ 
                Expanded( 
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                "Completion Reporting",
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Container(height: 10),
                              Text(
                                "Click the button below to either see the graph of completion, or refresh the data, to reflect new data...",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  const Spacer(),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.transparent,
                                    ),
                                    child: const Text(
                                      "Show/Hide Graph",
                                      style: TextStyle(color: MyColorsSample.accent),
                                    ),
                                    onPressed: toggleGraphVisibility,
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.transparent,
                                    ),
                                    child: const Text(
                                      "Refresh",
                                      style: TextStyle(color: MyColorsSample.accent),
                                    ),
                                    onPressed: () async {
                                      setState(() {
                                        shouldShowGraph = true;
                                      });
                                      fetchALLData();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(height: 5),
                      ],
                    ),
                  ),
                ),
              ],
            ),






        ],
          ),
        ),
      ),
    );
  }


  Widget buildCurvedNavigationBar() {
    return CurvedNavigationBar(










      key: _bottomNavigationKey,
      index: 0,
      height: 60.0,
      items: <Widget>[
        Icon(Icons.add, size: 30),
        Icon(Icons.list, size: 30),
        Icon(Icons.compare_arrows, size: 30),
        Icon(Icons.call_split, size: 30),
        Icon(Icons.perm_identity, size: 30),
      ],
      color: Colors.white,
      buttonBackgroundColor: Colors.white,
      backgroundColor: Color.fromRGBO(248, 225, 209, 1),
      animationCurve: Curves.easeInOut,
      animationDuration: Duration(milliseconds: 600),
      onTap: (index) {
        setState(() {
          _page = index;
          navigateToPage(index);
          //pageNavigator(index);
        });
      },
      letIndexChange: (index) => true,
    );





  }


Widget pageNavigator(int index) {
  if (index == 2) {
    return DialerContactsView(listName: selectedList,);
  } else {
    // Return something else or null if index is not equal to 2
    return Container(); // You can replace this with the appropriate widget
  }
}


  void navigateToPage(int index) {
    switch (index) {
      case 0:
        // Navigate to the first page
        //Navigator.pushNamed(context, ListRoute1);


        break;
      case 1:
        // Navigate to the second page
        // Navigator.pushReplacementNamed(context, '/second_page');
        //Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DialerViewCopy()));
        //return DialerViewCopy();
        
        break;
      // Add cases for other pages as needed
    }
  }








}
